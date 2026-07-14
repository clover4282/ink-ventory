class ProductSearch
  RateLimited = Class.new(StandardError)

  def self.call(query:, user:, track_new: false)
    new(query: query, user: user, track_new: track_new).call
  end

  def initialize(query:, user:, track_new:)
    @text = SearchQuery.normalize(query)
    @user = user
    @track_new = track_new
  end

  def call
    raise ArgumentError, "검색어를 입력해 주세요." if @text.blank?
    enforce_rate_limit! if @user
    SiteRegistry.ensure_sites!
    search_query = SearchQuery.find_or_create_by!(normalized_query: @text) { |record| record.query = @text }
    first_search = search_query.last_searched_at.nil?

    Site.available.find_each do |site|
      response = fetch(site, SiteRegistry.search_url(site, @text))
      next unless response&.status == 200
      SearchResultParser.call(response.body, base_url: site.base_url).each do |result|
        next unless FountainPenFilter.match?(result[:title])

        listing = Listing.find_or_create_by!(canonical_url: result[:resolved].canonical_url) do |record|
          record.site = site
          record.external_id = result[:resolved].external_id
          record.title = result[:title]
          record.next_check_at = Time.current
        end
        candidate = SearchCandidate.find_or_create_by!(search_query: search_query, listing: listing) do |record|
          record.first_seen_at = Time.current
        end
        if @track_new && !first_search && candidate.previously_new_record?
          listing.change_events.create!(kind: "NEW_SEARCH_RESULT", search_query: search_query, occurred_at: Time.current, current_value: { "title" => listing.title })
        end
      end
    rescue HttpFetcher::Error, SearchResultParser::Error => error
      Rails.logger.warn("search failed site=#{site.code}: #{error.class}: #{error.message}")
      next
    end
    search_query.update!(last_searched_at: Time.current, next_search_at: 1.day.from_now)
    search_query
  end

  private
    def enforce_rate_limit!
      @user.search_attempts.where("created_at < ?", 1.hour.ago).delete_all
      recent_count = SearchAttempt.where(user: @user).where("created_at >= ?", 1.minute.ago).count
      raise RateLimited, "검색은 1분에 10번까지 가능합니다." if recent_count >= 10
      SearchAttempt.create!(user: @user)
    end

    def fetch(site, url)
      SiteRequestThrottle.call(site) { HttpFetcher.call(url) }
    end
end
