require "test_helper"

class CatalogDiscoveryTest < ActiveSupport::TestCase
  test "discovers the fountain pen category and paginated products" do
    site = Site.create!(code: "bestpen", name: "베스트펜", base_url: "https://bestpen.kr", parser_kind: "makeshop", min_delay_seconds: 0)
    responses = {
      "https://bestpen.kr" => response("https://bestpen.kr", "<html></html>"),
      "https://bestpen.kr/shop/shopbrand.html?xcode=038&mcode=002&type=Y" => response("https://bestpen.kr/shop/shopbrand.html?xcode=038&mcode=002&type=Y", <<~HTML),
        <div class="cat-curation"><a href="/shop/shopdetail.html?branduid=99"><img alt="추천 상품"></a></div>
        <div class="item-wrap">
          <a href="/shop/shopdetail.html?branduid=3"><img alt="카테고리 만년필"></a>
          <a href="/shop/shopdetail.html?branduid=5"><img alt="볼펜 기프트 세트"></a>
        </div>
        <a href="?xcode=038&mcode=002&type=Y&page=2">2</a>
      HTML
      "https://bestpen.kr/shop/shopbrand.html?xcode=038&mcode=002&type=Y&page=2" => response("https://bestpen.kr/shop/shopbrand.html?xcode=038&mcode=002&type=Y&page=2", '<div class="item-wrap"><a href="/shop/shopdetail.html?branduid=4"><img alt="다음 페이지 만년필"></a></div>'),
      "https://bestpen.kr/shop/shopbrand.html?xcode=038&mcode=005&type=Y" => response("https://bestpen.kr/shop/shopbrand.html?xcode=038&mcode=005&type=Y", "<html></html>"),
      "https://bestpen.kr/shop/shopbrand.html?xcode=038&mcode=003&type=Y" => response("https://bestpen.kr/shop/shopbrand.html?xcode=038&mcode=003&type=Y", "<html></html>")
    }

    result = CatalogDiscovery.call(site, fetcher: ->(url, **) { responses.fetch(url) })

    assert_equal({ found: 2, created: 2, pages: 5 }, result)
    assert_equal %w[3 4], site.listings.order(:external_id).pluck(:external_id)
    assert_equal "다음 페이지 만년필", site.listings.find_by!(external_id: "4").title
  end

  test "keeps fountain pen sets and excludes penlog accessories" do
    site = Site.create!(code: "penlog", name: "펜로그", base_url: "https://www.myungdongmall.com", parser_kind: "cafe24", min_delay_seconds: 0)
    search_url = SiteRegistry.search_url(site, "만년필")
    responses = {
      site.base_url => response(site.base_url, "<html></html>"),
      search_url => response(search_url, <<~HTML)
        <div class="xans-search-result">
          <a href="/product/detail.html?product_no=1"><img alt="세일러 만년필"></a>
          <a href="/product/detail.html?product_no=2"><img alt="만년필용 잉크"></a>
          <a href="/product/detail.html?product_no=4"><img alt="세일러 만년필+잉크 세트"></a>
        </div>
        <a href="?keyword=%EB%A7%8C%EB%85%84%ED%95%84&page=2&CategoryUrl=%2Fproduct%2Flist.html">2</a>
      HTML
    }
    page_two_url = "#{search_url}&page=2"
    responses[page_two_url] = response(page_two_url, '<div class="xans-search-result"><a href="/product/detail.html?product_no=3"><img alt="Pilot Fountain Pen"></a></div>')

    result = CatalogDiscovery.call(site, fetcher: ->(url, **) { responses.fetch(url) })

    assert_equal({ found: 3, created: 3, pages: 3 }, result)
    assert_equal %w[1 3 4], site.listings.order(:external_id).pluck(:external_id)
  end

  test "excludes accessories incorrectly assigned to a fountain pen category" do
    site = Site.create!(code: "blueblack", name: "블루블랙", base_url: "https://www.blueblack.co.kr", parser_kind: "cafe24", min_delay_seconds: 0)
    catalog_url = "https://www.blueblack.co.kr/product/list.html?cate_no=192"
    responses = {
      site.base_url => response(site.base_url, "<html></html>"),
      catalog_url => response(catalog_url, <<~HTML)
        <div class="xans-product-listnormal">
          <a href="/product/detail.html?product_no=1"><img alt="세일러 만년필"></a>
          <a href="/product/detail.html?product_no=2"><img alt="세일러 프로기어 슬림 14K 문라이트"></a>
          <a href="/product/detail.html?product_no=3"><img alt="라미 컨버터"></a>
          <a href="/product/detail.html?product_no=4"><img alt="쉐퍼 만년필+볼펜 세트"></a>
        </div>
      HTML
    }

    result = CatalogDiscovery.call(site, fetcher: ->(url, **) { responses.fetch(url) })

    assert_equal({ found: 3, created: 3, pages: 2 }, result)
    assert_equal %w[1 2 4], site.listings.order(:external_id).pluck(:external_id)
  end

  private
    def response(url, body)
      HttpFetcher::Response.new(status: 200, body: body, etag: nil, last_modified: nil, url: url)
    end
end
