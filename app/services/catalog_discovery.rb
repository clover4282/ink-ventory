require "set"

class CatalogDiscovery
  MAX_PAGES = 200

  def self.call(site, fetcher: HttpFetcher)
    new(site, fetcher: fetcher).call
  end

  def initialize(site, fetcher:)
    @site = site
    @fetcher = fetcher
    @products = {}
    @seen_pages = Set.new
  end

  def call
    home = fetch_page(@site.base_url)
    catalog_urls(home).each { |url| discover_catalog(url) } if home

    created = save_products
    { found: @products.size, created: created, pages: @seen_pages.size }
  end

  private
    def discover_catalog(url)
      response = fetch_page(url)
      return unless response

      collect_products(response)
      max_page = pagination_pages(response).max.to_i.clamp(1, MAX_PAGES)
      2.upto(max_page) do |page|
        page_response = fetch_page(url_with_page(url, page))
        collect_products(page_response) if page_response
      end
    end

    def collect_products(response)
      document = Nokogiri::HTML5(response.body)
      selector = {
        "bestpen" => ".item-wrap",
        "blueblack" => ".xans-product-listnormal",
        "pengalleria" => ".prd-list:not(.recmd-prd-list)",
        "penlog" => ".xans-search-result"
      }.fetch(@site.code)
      catalog_html = document.css(selector).map(&:to_html).join

      SearchResultParser.call(catalog_html, base_url: response.url).each do |result|
        trusted_category = %w[blueblack pengalleria].include?(@site.code)
        next unless FountainPenFilter.match?(result[:title], trusted_category: trusted_category)
        add_product(result[:resolved].canonical_url, title: result[:title])
      end
    end

    def add_product(url, title: nil)
      uri = URI.parse(url.to_s)
      uri.scheme = "https" if uri.scheme == "http" && SiteRegistry.allowed_host?(uri.host)
      resolved = SiteRegistry.resolve(uri.to_s)
      return unless resolved.code == @site.code

      existing = @products[resolved.canonical_url]
      @products[resolved.canonical_url] = { resolved: resolved, title: title.presence || existing&.dig(:title) }
    rescue URI::InvalidURIError, SiteRegistry::UnsupportedUrl
      nil
    end

    def catalog_urls(response)
      if @site.code == "bestpen"
        return %w[002 005 003].map { |code| "https://bestpen.kr/shop/shopbrand.html?xcode=038&mcode=#{code}&type=Y" }
      end
      return [ "https://www.blueblack.co.kr/product/list.html?cate_no=192" ] if @site.code == "blueblack"
      return [ SiteRegistry.search_url(@site, "만년필") ] if @site.code == "penlog"

      document = Nokogiri::HTML5(response.body)
      document.css("a[href]").filter_map do |anchor|
        uri = absolute_uri(response.url, anchor["href"])
        valid = anchor.text.squish == "만년필" && uri.path == "/shop/shopbrand.html"
        normalized_page_url(uri) if valid && site_host?(uri.host)
      rescue URI::InvalidURIError
        nil
      end.uniq
    end

    def pagination_pages(response)
      current = URI.parse(response.url)
      current_params = URI.decode_www_form(current.query.to_s).to_h.except("page")

      Nokogiri::HTML5(response.body).css("a[href]").filter_map do |anchor|
        uri = absolute_uri(response.url, anchor["href"])
        params = URI.decode_www_form(uri.query.to_s).to_h
        page = params.delete("page")
        page&.to_i if uri.path == current.path && current_params.all? { |key, value| params[key] == value }
      rescue URI::InvalidURIError
        nil
      end
    end

    def url_with_page(url, page)
      uri = URI.parse(url)
      params = URI.decode_www_form(uri.query.to_s).reject { |key, _value| key == "page" }
      params << [ "page", page.to_s ]
      uri.query = URI.encode_www_form(params)
      uri.to_s
    end

    def normalized_page_url(uri)
      uri.scheme = "https"
      uri.fragment = nil
      params = URI.decode_www_form(uri.query.to_s).reject { |key, _value| key == "page" }
      uri.query = URI.encode_www_form(params)
      uri.to_s
    end

    def site_host?(host)
      SiteRegistry::CONFIG.fetch(@site.code)[:hosts].include?(host.to_s.downcase)
    end

    def absolute_uri(base_url, href)
      URI.parse(URI.join(base_url, href).to_s)
    rescue URI::InvalidURIError
      URI.parse(URI.join(base_url, URI::DEFAULT_PARSER.escape(href)).to_s)
    end

    def fetch_page(url)
      return if @seen_pages.include?(url)
      @seen_pages << url

      response = SiteRequestThrottle.call(@site) { @fetcher.call(url) }
      return unless response

      handle_site_status(response.status)
      response if response.status == 200
    rescue HttpFetcher::Error => error
      Rails.logger.warn("catalog discovery failed site=#{@site.code} url=#{url}: #{error.class}: #{error.message}")
      nil
    end

    def handle_site_status(status)
      if [ 403, 429 ].include?(status) || status.between?(500, 599)
        failures = @site.consecutive_failures + 1
        delay = [ 2**[ failures, 10 ].min, 24.hours.to_i / 60 ].min.minutes
        @site.update!(consecutive_failures: failures, backoff_until: delay.from_now)
      elsif status == 200 && (@site.consecutive_failures.positive? || @site.backoff_until)
        @site.update!(consecutive_failures: 0, backoff_until: nil)
      end
    end

    def save_products
      created = 0
      @products.each_value do |product|
        resolved = product[:resolved]
        listing = @site.listings.find_or_initialize_by(external_id: resolved.external_id)
        if listing.new_record?
          listing.assign_attributes(canonical_url: resolved.canonical_url, title: product[:title], next_check_at: Time.current)
          listing.save!
          created += 1
        elsif listing.title.blank? && product[:title].present?
          listing.update!(title: product[:title])
        end
      end
      created
    end
end
