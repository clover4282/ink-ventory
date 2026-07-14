class DiscoverCatalogsJob < ApplicationJob
  queue_as :crawlers
  limits_concurrency to: 1, key: -> { "discover-catalogs" }, duration: 12.hours

  def perform
    Site.available.find_each do |site|
      result = CatalogDiscovery.call(site)
      Rails.logger.info("catalog discovery site=#{site.code} found=#{result[:found]} created=#{result[:created]} pages=#{result[:pages]}")
    end
  end
end
