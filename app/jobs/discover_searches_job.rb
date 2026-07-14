class DiscoverSearchesJob < ApplicationJob
  queue_as :crawlers
  limits_concurrency to: 1, key: -> { "discover-searches" }, duration: 2.hours

  def perform
    SearchQuery.due.find_each { |query| ProductSearch.call(query: query.query, user: nil, track_new: true) }
  end
end
