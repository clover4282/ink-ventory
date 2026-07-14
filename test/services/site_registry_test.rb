require "test_helper"

class SiteRegistryTest < ActiveSupport::TestCase
  test "normalizes desktop and mobile product urls" do
    desktop = SiteRegistry.resolve("https://www.blueblack.co.kr/product/detail.html?product_no=42&cate_no=1")
    mobile = SiteRegistry.resolve("https://m.blueblack.co.kr/product/라미-사파리/42/category/1/display/2/")

    assert_equal desktop.canonical_url, mobile.canonical_url
    assert_equal "https://www.blueblack.co.kr/product/detail.html?product_no=42", desktop.canonical_url
  end

  test "normalizes makeshop urls" do
    result = SiteRegistry.resolve("https://m.bestpen.kr/shop/shopdetail.html?branduid=1234&xcode=001")

    assert_equal "bestpen", result.code
    assert_equal "https://bestpen.kr/shop/shopdetail.html?branduid=1234", result.canonical_url
  end

  test "accepts the current penlog brand domain" do
    result = SiteRegistry.resolve("https://penlog.co.kr/product/detail.html?product_no=6788")

    assert_equal "penlog", result.code
    assert_equal "https://www.myungdongmall.com/product/detail.html?product_no=6788", result.canonical_url
  end

  test "rejects unsupported schemes and domains" do
    assert_raises(SiteRegistry::UnsupportedUrl) { SiteRegistry.resolve("http://bestpen.kr/shop/shopdetail.html?branduid=1") }
    assert_raises(SiteRegistry::UnsupportedUrl) { SiteRegistry.resolve("https://127.0.0.1/product/detail.html?product_no=1") }
    assert_raises(SiteRegistry::UnsupportedUrl) { SiteRegistry.resolve("https://example.com/product/detail.html?product_no=1") }
  end

  test "provides an https logo for every supported store" do
    SiteRegistry::CONFIG.each_key do |code|
      assert_match %r{\Ahttps://}, SiteRegistry.logo_url(code)
    end
  end
end
