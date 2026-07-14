class SearchResultParser
  Error = Class.new(StandardError)

  def self.call(html, base_url:)
    document = Nokogiri::HTML5(html)
    document.css("a[href]").filter_map do |anchor|
      href = anchor["href"]
      next unless href&.match?(%r{shopdetail|product/(?:detail|[^/]+/\d+)|product_no=})
      absolute_url = URI.join(base_url, URI::DEFAULT_PARSER.escape(href)).to_s
      resolved = SiteRegistry.resolve(absolute_url)
      title = anchor.at_css("img")&.[]("alt")&.squish.presence || anchor.text.squish.presence
      next if title.blank? || title.match?(/\A(?:이전|다음|\s)+\z/)
      title = title.sub(/\A상품명\s*:\s*/, "")
      { resolved: resolved, title: title }
    rescue URI::InvalidURIError, SiteRegistry::UnsupportedUrl
      nil
    end.uniq { |result| result[:resolved].canonical_url }
  end
end
