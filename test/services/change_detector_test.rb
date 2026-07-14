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

  test "target price fires only on downward crossing and rearms above target" do
    subscription = @group.subscriptions.create!(listing: @listing, target_price_cents: 80_000)
    time = Time.zone.parse("2026-07-14 12:00")
    ChangeDetector.observe(@listing, state(price: 100_000), at: time)

    confirm(state(price: 70_000), time + 2.minutes)
    assert_equal 1, ChangeEvent.where(kind: "TARGET_REACHED").count
    assert_not subscription.reload.target_armed?

    confirm(state(price: 90_000), time + 5.minutes)
    assert subscription.reload.target_armed?
    confirm(state(price: 70_000), time + 8.minutes)
    assert_equal 2, ChangeEvent.where(kind: "TARGET_REACHED").count
  end

  test "daily digest only includes the subscribed option" do
    @group.subscriptions.create!(listing: @listing, variant_external_id: "EF")
    matching = @listing.change_events.create!(kind: "PRICE_CHANGED", variant_external_id: "EF", occurred_at: Time.current)
    @listing.change_events.create!(kind: "PRICE_CHANGED", variant_external_id: "F", occurred_at: Time.current)

    delivery = DigestBuilder.call(@user)

    assert_equal [ matching.id ], delivery.metadata["event_ids"]
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
