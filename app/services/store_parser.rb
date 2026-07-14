class StoreParser
  ParseError = Class.new(StandardError)

  def self.call(html, parser_kind:, page_url: nil)
    new(html, parser_kind: parser_kind, page_url: page_url).call
  end

  def initialize(html, parser_kind:, page_url:)
    @document = Nokogiri::HTML5(html)
    @parser_kind = parser_kind
    @page_url = page_url
  end

  def call
    product = json_ld_product
    title = product&.dig("name").presence || text_at("h3.tit-prd") || text_at("meta[property='og:title']", "content") || text_at("h1")
    raise ParseError, "상품명을 찾지 못했습니다." if title.blank?

    offers = wrap(product&.[]("offers")).flat_map do |offer|
      offer.is_a?(Hash) && offer["@type"] == "AggregateOffer" ? wrap(offer["offers"]) : offer
    end
    raw_offers = product&.[]("offers")
    aggregate_price = raw_offers.is_a?(Hash) ? raw_offers["lowPrice"] : nil
    base_price = price_value(aggregate_price) || price_value(offers.first&.dig("price")) || html_price

    aggregate_availability = raw_offers["availability"] if raw_offers.is_a?(Hash)
    product_availability = offers_availability(offers, aggregate_availability)
    product_availability = options_availability if product_availability == "unknown"
    product_availability = html_availability if product_availability == "unknown"

    ListingState.new(
      title: title.squish, currency: offers.first&.dig("priceCurrency").presence || "KRW",
      base_price_cents: base_price, availability: product_availability || "unknown", variants: [],
      image_url: product_image(product)
    )
  end

  private
    def json_ld_product
      @document.css("script[type='application/ld+json']").each do |node|
        parsed = JSON.parse(node.text)
        candidates = wrap(parsed).flat_map { |item| item.is_a?(Hash) && item["@graph"] ? wrap(item["@graph"]) : item }
        product = candidates.find { |item| item.is_a?(Hash) && Array(item["@type"]).include?("Product") }
        return product if product
      rescue JSON::ParserError
        next
      end
      nil
    end

    def options_availability
      option_nodes = if @parser_kind == "makeshop"
        @document.css("select.basic_option option, select[id='MK_p_s_0'] option")
      else
        @document.css("select[id^='product_option_id'] option")
      end
      options = option_nodes.uniq.filter do |option|
        name = option.text.squish
        name.present? && option["value"].present? && !name.match?(/선택|필수/i) && !name.match?(/\A[-─]+\z/)
      end
      return "unknown" if options.empty?
      options.any? { |option| !option["disabled"] && !option.text.match?(/품절|sold\s*out/i) } ? "in_stock" : "out_of_stock"
    end

    def offers_availability(offers, aggregate_availability)
      availabilities = offers.filter_map { |offer| normalize_availability(offer["availability"]) if offer.is_a?(Hash) }
      availabilities << normalize_availability(aggregate_availability)
      return "in_stock" if availabilities.include?("in_stock")
      return "out_of_stock" if availabilities.include?("out_of_stock")
      "unknown"
    end

    def html_price
      selectors = [ "meta[property='product:price:amount']", "meta[itemprop='price']", "[itemprop='price']" ]
      selectors.each do |selector|
        node = @document.at_css(selector)
        price = price_value(node&.[]("content") || node&.text)
        return price if price
      end
      [ ".sell_price", "td.price" ].each do |selector|
        @document.css(selector).each do |node|
          price = price_value(node.text)
          return price if price
        end
      end
      nil
    end

    def html_availability
      if @parser_kind == "makeshop"
        return "out_of_stock" if @document.at_css("div.soldout")
        return "in_stock" if @document.at_css(".prd-btns .btn_buy")
      else
        buttons = @document.css(".xans-product-action a, .xans-product-action button, .productAction .btnSubmit").reject { |node| node["class"].to_s.split.include?("displaynone") }
        return "out_of_stock" if buttons.any? { |node| node.text.match?(/품절|sold\s*out/i) }
        return "in_stock" if buttons.any? { |node| node.text.match?(/(?:바로\s*)?구매하기|장바구니|buy/i) }
      end
      "unknown"
    end

    def product_image(product)
      selectors = if @parser_kind == "cafe24"
        [ "img.BigImage", "img.bigImage" ]
      else
        [ "meta[property='og:image']", "img.detail_image" ]
      end
      candidates = selectors.map do |selector|
        node = @document.at_css(selector)
        node&.[](node.name == "meta" ? "content" : "src")
      end
      candidates << product&.[]("image")
      candidates << text_at("meta[property='og:image']", "content") if @parser_kind == "cafe24"
      candidates.filter_map { |candidate| absolute_https_url(candidate) }.first
    end

    def absolute_https_url(value)
      value = value.first if value.is_a?(Array)
      value = value["url"] || value["@id"] if value.is_a?(Hash)
      return if value.blank?
      uri = URI.parse(value.to_s)
      return if !uri.absolute? && @page_url.blank?
      uri = URI.join(@page_url, value.to_s) unless uri.absolute?
      uri.to_s if uri.is_a?(URI::HTTPS)
    rescue URI::InvalidURIError, TypeError
      nil
    end

    def text_at(selector, attribute = nil)
      node = @document.at_css(selector)
      attribute ? node&.[](attribute) : node&.text
    end

    def price_value(value)
      digits = value.to_s.gsub(/[^\d]/, "")
      digits.present? ? digits.to_i : nil
    end

    def normalize_availability(value)
      text = value.to_s.downcase
      return "out_of_stock" if text.match?(/outofstock|soldout|품절|unavailable/)
      return "in_stock" if text.match?(/instock|limitedavailability|재고\s*있|판매중/)
      "unknown"
    end

    def wrap(value)
      value.is_a?(Array) ? value : value.nil? ? [] : [ value ]
    end
end
