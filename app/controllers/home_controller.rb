class HomeController < ApplicationController
  def index
    @catalog_query = params[:q].to_s.unicode_normalize(:nfc).squish.first(100)
    crawled_listings = Listing.joins(:site).where.not(last_success_at: nil)
    @total_crawled_listing_count = crawled_listings.count
    if @catalog_query.present?
      pattern = "%#{Listing.sanitize_sql_like(@catalog_query)}%"
      @crawled_listing_count = crawled_listings.where("LOWER(listings.title) LIKE LOWER(:pattern) OR LOWER(sites.name) LIKE LOWER(:pattern)", pattern: pattern).count
    else
      @crawled_listing_count = @total_crawled_listing_count
    end
    @crawled_listings = crawled_listings.includes(:site, :variants).order(last_success_at: :desc)
    return unless current_user
    @subscriptions = current_user.subscriptions.includes(listing: %i[site variants]).order(created_at: :desc)
    @search_watches = current_user.search_watches.includes(search_query: { search_candidates: { listing: :site } })
    @recent_events = ChangeEvent.where(listing_id: @subscriptions.select(:listing_id)).includes(listing: :site).order(occurred_at: :desc).limit(20)
  end
end
