class HomeController < ApplicationController
  def index
    @catalog_query = params[:q].to_s.unicode_normalize(:nfc).squish.first(100)
    @crawled_listings = Listing.joins(:site).where.not(last_success_at: nil).includes(:site).order(last_success_at: :desc).to_a
    @total_crawled_listing_count = @crawled_listings.size
    if @catalog_query.present?
      scores = @crawled_listings.to_h { |listing| [ listing.id, CatalogSearch.score("#{listing.title} #{listing.site.name}", @catalog_query) ] }
      @crawled_listing_count = scores.count { |_id, score| score.positive? }
      @crawled_listings = @crawled_listings.each_with_index.sort_by { |(listing, index)| [ -scores.fetch(listing.id), index ] }.map(&:first)
    else
      @crawled_listing_count = @total_crawled_listing_count
    end
    listing_ids = @crawled_listings.map(&:id)
    @catalog_sites = @crawled_listings.map(&:site).uniq(&:id).sort_by(&:name)
    @recent_restocked_at = ChangeEvent.versioned.where(listing_id: listing_ids, kind: "RESTOCKED", occurred_at: 10.days.ago..).group(:listing_id).maximum(:occurred_at)
    @liked_listing_ids = current_user ? ListingLike.where(user: current_user, listing_id: listing_ids).pluck(:listing_id).index_with(true) : {}
  end
end
