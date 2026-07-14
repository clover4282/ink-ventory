class CollectListingJob < ApplicationJob
  queue_as :crawlers

  def perform(listing_id)
    ListingCollector.call(Listing.find(listing_id))
  end
end
