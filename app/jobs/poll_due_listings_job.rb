class PollDueListingsJob < ApplicationJob
  queue_as :crawlers
  limits_concurrency to: 1, key: -> { "poll-due-listings" }, duration: 30.minutes

  def perform
    Listing.due.limit(100).each { |listing| ListingCollector.call(listing) }
  end
end
