require "test_helper"

class SendMailDeliveryJobTest < ActiveJob::TestCase
  setup do
    ActionMailer::Base.deliveries.clear
    site = Site.create!(code: "mail-test", name: "메일 테스트", base_url: "https://bestpen.kr", parser_kind: "makeshop")
    listing = site.listings.create!(external_id: "1", canonical_url: "https://bestpen.kr/product/1", title: "테스트 만년필")
    @user = User.create!(provider: "email", uid: "mail-user", email: "user@example.com")
    @address = @user.create_notification_address!(email: "user@example.com", verified_at: Time.current)
    group = @user.watch_groups.create!(name: "관심 상품")
    subscription = group.subscriptions.create!(listing: listing)
    event = listing.change_events.create!(
      kind: "RESTOCKED", previous_value: { "value" => "out_of_stock" },
      current_value: { "value" => "in_stock" }, occurred_at: Time.current
    )
    @delivery = @user.mail_deliveries.create!(
      kind: "event", recipient: @address.email, dedupe_key: "event-test",
      metadata: { "event_id" => event.id, "subscription_id" => subscription.id }, scheduled_at: Time.current
    )
  end

  test "sends an event once and cancels queued mail after notifications are disabled" do
    assert_difference "ActionMailer::Base.deliveries.size", 1 do
      SendMailDeliveryJob.perform_now(@delivery.id)
    end
    assert_equal "sent", @delivery.reload.status
    assert_equal [ @address.email ], ActionMailer::Base.deliveries.last.to

    assert_no_difference "ActionMailer::Base.deliveries.size" do
      SendMailDeliveryJob.perform_now(@delivery.id)
    end

    canceled = @user.mail_deliveries.create!(
      kind: "event", recipient: @address.email, dedupe_key: "canceled-event-test",
      metadata: @delivery.metadata, scheduled_at: Time.current
    )
    @address.update!(notifications_enabled: false)

    assert_no_difference "ActionMailer::Base.deliveries.size" do
      SendMailDeliveryJob.perform_now(canceled.id)
    end
    assert_equal "canceled", canceled.reload.status
  end
end
