class SiteRegistry
  UnsupportedUrl = Class.new(StandardError)

  CONFIG = {
    "bestpen" => {
      name: "베스트펜", base_url: "https://bestpen.kr", parser_kind: "makeshop",
      hosts: %w[bestpen.kr www.bestpen.kr m.bestpen.kr], id_param: "branduid",
      logo_url: "https://www.bestpen.kr/design/munku/be_new/bestpen_logo211.svg"
    },
    "blueblack" => {
      name: "블루블랙", base_url: "https://www.blueblack.co.kr", parser_kind: "cafe24",
      hosts: %w[blueblack.co.kr www.blueblack.co.kr m.blueblack.co.kr], id_param: "product_no",
      logo_url: "https://www.blueblack.co.kr/web/upload/category/editor/2026/03/24/b4d4c51f8e5308c8a0c81f6220ff15e6.png"
    },
    "pengalleria" => {
      name: "펜갤러리아", base_url: "https://pengalleria.com", parser_kind: "makeshop",
      hosts: %w[pengalleria.com www.pengalleria.com m.pengalleria.com], id_param: "branduid",
      logo_url: "https://pengalleria.com/design/pengall100/0772marketo/top_logo.png"
    },
    "penlog" => {
      name: "펜로그", base_url: "https://www.myungdongmall.com", parser_kind: "cafe24",
      hosts: %w[myungdongmall.com www.myungdongmall.com m.myungdongmall.com penlog.co.kr www.penlog.co.kr m.penlog.co.kr], id_param: "product_no",
      logo_url: "https://www.myungdongmall.com/web/upload/logo_off.png"
    }
  }.freeze

  Result = Data.define(:code, :external_id, :canonical_url)

  def self.resolve(raw_url)
    uri = URI.parse(URI::DEFAULT_PARSER.escape(raw_url.to_s.strip))
    raise UnsupportedUrl, "HTTPS 상품 URL만 등록할 수 있습니다." unless uri.is_a?(URI::HTTPS)

    code, config = CONFIG.find { |_key, value| value[:hosts].include?(uri.host.to_s.downcase) }
    raise UnsupportedUrl, "지원하지 않는 쇼핑몰입니다." unless config

    params = URI.decode_www_form(uri.query.to_s).to_h
    external_id = params[config[:id_param]] || product_id_from_path(uri.path, config[:parser_kind])
    raise UnsupportedUrl, "상품 번호를 찾을 수 없는 URL입니다." if external_id.blank?

    path = config[:parser_kind] == "makeshop" ? "/shop/shopdetail.html" : "/product/detail.html"
    query = URI.encode_www_form(config[:id_param] => external_id)
    Result.new(code: code, external_id: external_id.to_s, canonical_url: "#{config[:base_url]}#{path}?#{query}")
  rescue URI::InvalidURIError
    raise UnsupportedUrl, "올바른 URL을 입력해 주세요."
  end

  def self.ensure_sites!
    CONFIG.each do |code, config|
      Site.find_or_create_by!(code: code) do |site|
        site.name = config[:name]
        site.base_url = config[:base_url]
        site.parser_kind = config[:parser_kind]
      end
    end
  end

  def self.search_url(site, query)
    encoded = URI.encode_www_form_component(query)
    if site.parser_kind == "cafe24"
      "#{site.base_url}/product/search.html?keyword=#{encoded}"
    else
      "#{site.base_url}/shop/shopbrand.html?search=&prize1=#{encoded}"
    end
  end

  def self.logo_url(code)
    CONFIG.dig(code.to_s, :logo_url)
  end

  def self.allowed_host?(host)
    CONFIG.values.any? { |config| config[:hosts].include?(host.to_s.downcase) }
  end

  def self.safe_external_url(raw_url)
    uri = URI.parse(raw_url.to_s)
    uri.to_s if uri.is_a?(URI::HTTPS) && allowed_host?(uri.host)
  rescue URI::InvalidURIError
    nil
  end

  def self.product_id_from_path(path, parser_kind)
    return path[%r{/product/(?:[^/]+/)?(\d+)(?:/|\z)}, 1] if parser_kind == "cafe24"
    path[%r{/(\d+)(?:/|\z)}, 1]
  end
  private_class_method :product_id_from_path
end
