class CleanupDeliveryLogsJob < ApplicationJob
  queue_as :default

  def perform
    MailDelivery.where(status: %w[sent failed canceled]).where("updated_at < ?", 30.days.ago).delete_all
    Observation.where("observed_at < ?", 1.year.ago).delete_all
    SearchAttempt.where("created_at < ?", 1.day.ago).delete_all
    LoginChallenge.where("expires_at < ?", 1.day.ago).delete_all
  end
end
