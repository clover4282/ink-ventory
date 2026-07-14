require "net/http"
require "resolv"
require "ipaddr"

class HttpFetcher
  Error = Class.new(StandardError)
  UnsafeAddress = Class.new(Error)
  TooLarge = Class.new(Error)
  Response = Data.define(:status, :body, :etag, :last_modified, :url)

  MAX_BYTES = 5.megabytes
  USER_AGENT = ENV.fetch("CRAWLER_USER_AGENT", "Ink-ventory/1.0 (+mailto:contact@example.com)")

  def self.call(url, etag: nil, last_modified: nil, redirects: 5)
    uri = URI.parse(url)
    ip_address = validate_uri!(uri)
    request = Net::HTTP::Get.new(uri)
    request["User-Agent"] = USER_AGENT
    request["Accept"] = "text/html,application/xhtml+xml"
    request["If-None-Match"] = etag if etag.present?
    request["If-Modified-Since"] = last_modified if last_modified.present?

    http = Net::HTTP.new(uri.host, uri.port)
    http.ipaddr = ip_address
    http.use_ssl = true
    http.open_timeout = 10
    http.read_timeout = 15
    response = http.start { |connection| connection.request(request) }

    if redirect_response?(response)
      raise Error, "리디렉션이 너무 많습니다." if redirects.zero?
      raise Error, "리디렉션 대상이 없습니다." if response["location"].blank?
      target = URI.join(uri, response["location"]).to_s
      return call(target, etag: etag, last_modified: last_modified, redirects: redirects - 1)
    end

    body = response.body.to_s
    raise TooLarge, "응답이 5MB를 초과했습니다." if body.bytesize > MAX_BYTES

    Response.new(
      status: response.code.to_i,
      body: transcode(body, response["content-type"]),
      etag: response["etag"], last_modified: response["last-modified"], url: uri.to_s
    )
  rescue Timeout::Error, SocketError, SystemCallError, OpenSSL::SSL::SSLError => error
    raise Error, error.message
  end

  def self.redirect_response?(response)
    response.is_a?(Net::HTTPRedirection) && !response.is_a?(Net::HTTPNotModified)
  end
  private_class_method :redirect_response?

  def self.validate_uri!(uri)
    unless uri.is_a?(URI::HTTPS) && SiteRegistry.allowed_host?(uri.host)
      raise UnsafeAddress, "허용되지 않은 주소입니다."
    end

    addresses = Resolv.getaddresses(uri.host)
    raise UnsafeAddress, "호스트 주소를 확인할 수 없습니다." if addresses.empty?
    raise UnsafeAddress, "사설 네트워크 주소는 사용할 수 없습니다." unless addresses.all? { |address| public_ip?(address) }
    addresses.first
  end

  def self.public_ip?(address)
    ip = IPAddr.new(address)
    blocked = [
      "0.0.0.0/8", "10.0.0.0/8", "100.64.0.0/10", "127.0.0.0/8", "169.254.0.0/16",
      "172.16.0.0/12", "192.0.0.0/24", "192.168.0.0/16", "224.0.0.0/4",
      "::/128", "::1/128", "fc00::/7", "fe80::/10", "ff00::/8"
    ]
    blocked.none? { |range| IPAddr.new(range).include?(ip) }
  end
  private_class_method :public_ip?

  def self.transcode(body, content_type)
    charset = content_type.to_s[/charset\s*=\s*["']?([^;"']+)/i, 1]
    charset ||= body.byteslice(0, 8.kilobytes).to_s.force_encoding(Encoding::BINARY)[/charset\s*=\s*["']?([^;"'>]+)/in, 1]
    return body.force_encoding(Encoding::UTF_8).scrub if charset.blank? || charset.match?(/utf-?8/i)
    source_encoding = charset.match?(/euc-?kr/i) ? Encoding::CP949 : Encoding.find(charset)
    body.force_encoding(source_encoding).encode(Encoding::UTF_8, invalid: :replace, undef: :replace, replace: "�")
  rescue ArgumentError, Encoding::ConverterNotFoundError
    body.force_encoding(Encoding::UTF_8).scrub
  end
  private_class_method :transcode
end
