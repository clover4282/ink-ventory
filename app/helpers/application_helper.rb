module ApplicationHelper
  def safe_listing_url(listing)
    SiteRegistry.safe_external_url(listing.canonical_url)
  end
end
