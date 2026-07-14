class BuildDailyDigestsJob < ApplicationJob
  queue_as :mailers

  def perform
    User.includes(:notification_address).find_each { |user| DigestBuilder.call(user) }
  end
end
