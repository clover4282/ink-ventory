class ListingCollector
  def self.call(listing, fetcher: HttpFetcher)
    new(listing, fetcher: fetcher).call
  end

  def initialize(listing, fetcher:)
    @listing = listing
    @site = listing.site
    @fetcher = fetcher
  end

  def call
    response = SiteRequestThrottle.call(@site) do
      use_validators = @listing.image_url.present? && @listing.pending_state.blank?
      @fetcher.call(
        @listing.canonical_url,
        etag: use_validators ? @listing.etag : nil,
        last_modified: use_validators ? @listing.last_modified : nil
      )
    end
    return unless response

    case response.status
    when 200
      state = StoreParser.call(response.body, parser_kind: @site.parser_kind, page_url: response.url)
      attributes = { etag: response.etag, last_modified: response.last_modified, last_checked_at: Time.current }
      attributes[:image_url] = state.image_url if state.image_url.present?
      @listing.update!(attributes)
      reset_site_failures!
      ChangeDetector.observe(@listing, state)
    when 304
      @listing.update!(last_checked_at: Time.current, next_check_at: 10.minutes.from_now, consecutive_errors: 0)
      reset_site_failures!
    when 404
      record_error!
      if @listing.reload.consecutive_errors >= 3 && @listing.status != "removed"
        @listing.update!(status: "removed", next_check_at: 1.day.from_now)
        event = @listing.change_events.create!(kind: "REMOVED", previous_value: @listing.current_state || {}, current_value: {}, occurred_at: Time.current)
        ImmediateNotificationBuilder.call(event)
      end
    when 403, 429, 500..599
      backoff_site!
      record_error!
    else
      record_error!
    end
  rescue HttpFetcher::Error, StoreParser::ParseError => error
    Rails.logger.warn("collector failed listing=#{@listing.id}: #{error.class}: #{error.message}")
    record_error!
  end

  private
    def record_error!
      @listing.update!(
        consecutive_errors: @listing.consecutive_errors + 1,
        last_checked_at: Time.current, next_check_at: 10.minutes.from_now
      )
    end

    def backoff_site!
      failures = @site.consecutive_failures + 1
      delay = [ 2**[ failures, 10 ].min, 24.hours.to_i / 60 ].min.minutes
      @site.update!(consecutive_failures: failures, backoff_until: delay.from_now)
    end

    def reset_site_failures!
      @site.update!(consecutive_failures: 0, backoff_until: nil) if @site.consecutive_failures.positive? || @site.backoff_until
    end
end
