require "test_helper"

class ListingCollectorTest < ActiveSupport::TestCase
  test "does not send validators while confirming a pending change" do
    site = Site.create!(code: "penlog", name: "펜로그", base_url: "https://www.myungdongmall.com", parser_kind: "cafe24", min_delay_seconds: 0)
    listing = site.listings.create!(
      external_id: "1", canonical_url: "https://www.myungdongmall.com/product/detail.html?product_no=1",
      title: "테스트 만년필", image_url: "https://example.com/pen.jpg", last_modified: "yesterday"
    )
    listing.variants.create!(external_id: "EF", name: "EF촉", availability: "in_stock")
    html = <<~HTML
      <html><head><meta property="og:title" content="테스트 만년필"><meta property="product:price:amount" content="30,000"></head>
      <body><div class="xans-product-action"><a>구매하기</a></div></body></html>
    HTML
    pending_state = StoreParser.call(html, parser_kind: "cafe24").as_json
    listing.update!(
      status: "unknown", current_state: pending_state.merge("availability" => "unknown"),
      pending_state: pending_state, pending_seen_at: 2.minutes.ago
    )
    received_headers = nil
    fetcher = lambda do |url, **headers|
      received_headers = headers
      HttpFetcher::Response.new(status: 200, body: html, etag: nil, last_modified: nil, url: url)
    end

    ListingCollector.call(listing, fetcher: fetcher)

    assert_nil received_headers[:etag]
    assert_nil received_headers[:last_modified]
    assert_equal "in_stock", listing.reload.status
    assert_empty listing.variants
    assert_nil listing.pending_state
  end
end
