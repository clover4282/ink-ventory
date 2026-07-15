require "test_helper"

class ChangeDetectorTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @site = Site.create!(code: "test", name: "테스트", base_url: "https://bestpen.kr", parser_kind: "makeshop")
    @listing = @site.listings.create!(external_id: "1", canonical_url: "https://bestpen.kr/shop/shopdetail.html?branduid=1")
    @user = User.create!(provider: "google_oauth2", uid: "user-1", name: "테스터")
    @user.create_notification_address!(email: "user@example.com", verified_at: Time.current)
    @group = @user.watch_groups.create!(name: "관심 상품")
    clear_enqueued_jobs
  end

  test "stores first observation as baseline and confirms a restock before notifying" do
    @group.subscriptions.create!(listing: @listing)
    time = Time.zone.parse("2026-07-14 12:00")

    ChangeDetector.observe(@listing, state(price: 100_000, availability: "out_of_stock"), at: time)
    assert_empty ChangeEvent.all

    ChangeDetector.observe(@listing, state(price: 100_000, availability: "in_stock"), at: time + 2.minutes)
    assert_empty ChangeEvent.all
    assert_not_nil @listing.reload.pending_state

    ChangeDetector.observe(@listing, state(price: 100_000, availability: "in_stock"), at: time + 3.minutes)
    assert_equal [ "RESTOCKED" ], ChangeEvent.pluck(:kind)
    assert_equal 1, MailDelivery.count
    assert_equal 1, enqueued_jobs.count
  end

  test "uses a new parser version as a baseline without creating false changes" do
    old_state = state(price: 100_000, availability: "out_of_stock").as_json.merge("parser_version" => 1)
    @listing.update!(current_state: old_state, status: "out_of_stock")

    ChangeDetector.observe(@listing, state(price: 90_000, availability: "in_stock"), at: Time.zone.parse("2026-07-15 12:00"))

    assert_empty ChangeEvent.all
    assert_equal "in_stock", @listing.reload.status
    assert_equal ListingState::PARSER_VERSION, @listing.current_state["parser_version"]
    assert_equal ListingState::PARSER_VERSION, @listing.observations.last.state["parser_version"]
  end

  test "keeps confirmed price changes and notifies subscribers immediately" do
    @group.subscriptions.create!(listing: @listing)
    time = Time.zone.parse("2026-07-15 12:00")
    ChangeDetector.observe(@listing, state(price: 100_000), at: time)

    confirm(state(price: 90_000), time + 2.minutes)

    event = ChangeEvent.find_by!(kind: "PRICE_CHANGED")
    assert_equal({ "value" => 100_000 }, event.previous_value)
    assert_equal({ "value" => 90_000, "parser_version" => ListingState::PARSER_VERSION }, event.current_value)
    assert_equal 3, @listing.observations.count
    assert_equal [ "event" ], MailDelivery.pluck(:kind)
    assert_equal event.id, MailDelivery.first.metadata["event_id"]
  end

  test "notifies subscribers immediately when an in-stock product sells out" do
    @group.subscriptions.create!(listing: @listing)
    time = Time.zone.parse("2026-07-15 12:00")
    ChangeDetector.observe(@listing, state(price: 100_000, availability: "in_stock"), at: time)

    confirm(state(price: 100_000, availability: "out_of_stock"), time + 2.minutes)

    event = ChangeEvent.find_by!(kind: "SOLD_OUT")
    assert_equal [ event.id ], MailDelivery.pluck(:metadata).pluck("event_id")
  end

  test "notifies each subscriber once while collecting a shared listing once" do
    @group.subscriptions.create!(listing: @listing)
    second = User.create!(provider: "kakao", uid: "user-2", name: "둘째")
    second.create_notification_address!(email: "second@example.com", verified_at: Time.current)
    second.watch_groups.create!(name: "관심").subscriptions.create!(listing: @listing)
    time = Time.zone.parse("2026-07-14 12:00")

    ChangeDetector.observe(@listing, state(price: 10_000, availability: "out_of_stock"), at: time)
    ChangeDetector.observe(@listing, state(price: 10_000, availability: "in_stock"), at: time + 2.minutes)
    ChangeDetector.observe(@listing, state(price: 10_000, availability: "in_stock"), at: time + 3.minutes)

    assert_equal 1, Listing.count
    assert_equal 2, MailDelivery.count
    ChangeEvent.find_by!(kind: "RESTOCKED").then { |event| ImmediateNotificationBuilder.call(event) }
    assert_equal 2, MailDelivery.count
  end

  test "ignores legacy target prices and creates only price change events" do
    subscription = @group.subscriptions.create!(listing: @listing, target_price_cents: 80_000)
    time = Time.zone.parse("2026-07-14 12:00")
    ChangeDetector.observe(@listing, state(price: 100_000), at: time)

    confirm(state(price: 70_000), time + 2.minutes)
    assert_empty ChangeEvent.where(kind: "TARGET_REACHED")
    assert_equal [ "PRICE_CHANGED" ], MailDelivery.order(:id).map { |delivery| ChangeEvent.find(delivery.metadata["event_id"]).kind }
    assert subscription.reload.target_armed?
  end

  test "does not build daily digest mail" do
    @group.subscriptions.create!(listing: @listing)
    @listing.change_events.create!(kind: "SOLD_OUT", occurred_at: Time.current)
    @listing.change_events.create!(kind: "REMOVED", occurred_at: Time.current)

    assert_nil DigestBuilder.call(@user)
    assert_empty MailDelivery.all
  end

  test "does not schedule daily digest generation" do
    config = YAML.safe_load(ERB.new(Rails.root.join("config/recurring.yml").read).result, aliases: true)

    assert_not config.fetch("development").key?("build_daily_digests")
  end

  private
    def state(price:, availability: "in_stock")
      ListingState.new(title: "테스트 펜", currency: "KRW", base_price_cents: price, availability: availability, variants: [], image_url: nil)
    end

    def confirm(new_state, at)
      ChangeDetector.observe(@listing, new_state, at: at)
      ChangeDetector.observe(@listing, new_state, at: at + 1.minute)
    end
end
