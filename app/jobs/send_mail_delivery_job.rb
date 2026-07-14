class SendMailDeliveryJob < ApplicationJob
  queue_as :mailers

  def perform(delivery_id)
    delivery = MailDelivery.find(delivery_id)
    delivery.with_lock do
      return if delivery.status == "sent"
      return if delivery.status == "processing" && delivery.updated_at > 30.minutes.ago
      delivery.update!(status: "processing", attempts: delivery.attempts + 1, last_error: nil)
    end

    case delivery.kind
    when "verification" then NotificationMailer.verification(delivery).deliver_now
    when "event" then NotificationMailer.event_alert(delivery).deliver_now
    when "digest" then NotificationMailer.digest(delivery).deliver_now
    else raise ArgumentError, "unknown delivery kind: #{delivery.kind}"
    end
    delivery.update!(status: "sent", sent_at: Time.current)
  rescue StandardError => error
    if delivery&.persisted?
      minutes = [ 2**[ delivery.attempts, 10 ].min, 24.hours.to_i / 60 ].min
      delivery.update!(status: "failed", last_error: error.message.truncate(2_000), scheduled_at: minutes.minutes.from_now)
    end
    Rails.logger.error("mail delivery failed id=#{delivery_id}: #{error.class}: #{error.message}")
  end
end
