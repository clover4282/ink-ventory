require "test_helper"

class NotificationAddressTest < ActiveSupport::TestCase
  test "changing an address requires verification again" do
    user = User.create!(provider: "google_oauth2", uid: "mail-user")
    address = user.create_notification_address!(email: "old@example.com", verified_at: Time.current)

    address.email = "new@example.com"
    address.reset_verification!
    address.save!

    assert_nil address.verified_at
    assert address.notifications_enabled?
  end

  test "verification mail can be queued before the address is verified" do
    user = User.create!(provider: "google_oauth2", uid: "verify-user")
    address = user.create_notification_address!(email: "new@example.com")

    assert_difference "MailDelivery.count", 1 do
      NotificationOutbox.enqueue(user: user, kind: "verification", dedupe_key: "verify:#{address.id}", metadata: {})
    end
  end
end
