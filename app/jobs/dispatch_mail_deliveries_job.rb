class DispatchMailDeliveriesJob < ApplicationJob
  queue_as :mailers
  limits_concurrency to: 1, key: -> { "dispatch-mail-deliveries" }, duration: 10.minutes

  def perform
    MailDelivery.where(status: "processing").where("updated_at < ?", 30.minutes.ago).update_all(status: "failed", scheduled_at: Time.current)
    MailDelivery.due.limit(100).pluck(:id).each { |id| SendMailDeliveryJob.perform_later(id) }
  end
end
