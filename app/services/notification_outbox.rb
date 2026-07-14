class NotificationOutbox
  def self.enqueue(user:, kind:, dedupe_key:, metadata:, scheduled_at: Time.current)
    address = user.notification_address
    return unless address
    return unless kind == "verification" || (address.verified_at? && address.notifications_enabled?)

    delivery = MailDelivery.find_or_create_by!(dedupe_key: dedupe_key) do |record|
      record.user = user
      record.kind = kind
      record.recipient = address.email
      record.metadata = metadata
      record.scheduled_at = scheduled_at
    end
    SendMailDeliveryJob.perform_later(delivery.id) if delivery.previously_new_record?
    delivery
  end
end
