require "test_helper"

class PublicChangesTest < ActionDispatch::IntegrationTest
  test "shows recent confirmed stock and price changes without login" do
    site = Site.create!(code: "changes-test", name: "변동 테스트", base_url: "https://changes.example.test", parser_kind: "cafe24")
    listing = site.listings.create!(
      external_id: "pen", canonical_url: "https://bestpen.kr/shop/shopdetail.html?branduid=pen",
      title: "변동 만년필", image_url: "https://images.example.test/pen.jpg"
    )
    listing.change_events.create!(
      kind: "RESTOCKED", previous_value: { "value" => "out_of_stock" },
      current_value: { "value" => "in_stock", "parser_version" => ListingState::PARSER_VERSION }, occurred_at: 2.hours.ago
    )
    listing.change_events.create!(
      kind: "PRICE_CHANGED", previous_value: { "value" => 40_000 },
      current_value: { "value" => 35_000, "parser_version" => ListingState::PARSER_VERSION }, occurred_at: 1.hour.ago
    )
    listing.change_events.create!(kind: "SOLD_OUT", occurred_at: 3.hours.ago)
    listing.change_events.create!(
      kind: "REMOVED", current_value: { "parser_version" => ListingState::PARSER_VERSION }, occurred_at: 30.minutes.ago
    )

    get changes_path

    assert_response :success
    assert_select "h1", text: "입고·품절·가격 변동"
    assert_select "nav a[href='#{changes_path}'][aria-current='page']", text: "변동 내역"
    assert_select "[data-change-event='PRICE_CHANGED']", text: /40,000원.*35,000원/
    assert_select "[data-change-event='RESTOCKED']", text: /품절.*재고 있음/
    assert_select "[data-change-event='SOLD_OUT']", count: 0
    assert_select "[data-change-event='REMOVED']", count: 0
    assert_select "img.product-image[src='https://images.example.test/pen.jpg']"
    assert_select "a[href='#{listing_path(listing)}']", text: "변동 만년필"
    assert_equal %w[PRICE_CHANGED RESTOCKED], css_select("[data-change-event]").map { |node| node["data-change-event"] }
  end
end
