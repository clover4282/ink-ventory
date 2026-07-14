require "test_helper"

class HttpFetcherTest < ActiveSupport::TestCase
  test "decodes makeshop euc kr declared in html" do
    body = "<meta http-equiv='content-type' content='text/html;charset=EUC-KR'>".b
    body << "만년필".encode(Encoding::CP949).b

    decoded = HttpFetcher.send(:transcode, body, "text/html")

    assert_includes decoded, "만년필"
    assert_predicate decoded, :valid_encoding?
  end

  test "classifies private and public addresses for dns rebinding protection" do
    assert_not HttpFetcher.send(:public_ip?, "127.0.0.1")
    assert_not HttpFetcher.send(:public_ip?, "192.168.1.2")
    assert HttpFetcher.send(:public_ip?, "8.8.8.8")
  end

  test "returns not modified without treating it as a redirect" do
    not_modified = Net::HTTPNotModified.new("1.1", "304", "Not Modified")
    found = Net::HTTPFound.new("1.1", "302", "Found")

    assert_not HttpFetcher.send(:redirect_response?, not_modified)
    assert HttpFetcher.send(:redirect_response?, found)
  end
end
