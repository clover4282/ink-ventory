require "test_helper"

class SearchResultParserTest < ActiveSupport::TestCase
  test "prefers an image alt title and deduplicates repeated cafe24 links" do
    html = <<~HTML
      <a href="/product/detail.html?product_no=42">이전 다음</a>
      <a href="/product/detail.html?product_no=42"><img alt="라미 사파리 만년필"></a>
      <a href="/product/detail.html?product_no=42">상품명 : 라미 사파리 만년필</a>
    HTML

    results = SearchResultParser.call(html, base_url: "https://www.blueblack.co.kr")

    assert_equal 1, results.size
    assert_equal "라미 사파리 만년필", results.first[:title]
  end
end
