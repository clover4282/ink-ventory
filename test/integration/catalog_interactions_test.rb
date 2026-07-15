require "test_helper"

class CatalogInteractionsTest < ActionDispatch::IntegrationTest
  setup do
    @site = Site.create!(code: "catalog-test", name: "카탈로그 테스트", base_url: "https://catalog.example.test", parser_kind: "cafe24")
    @listing = @site.listings.create!(
      external_id: "popular", canonical_url: "https://catalog.example.test/popular",
      title: "인기 만년필", status: "in_stock", base_price_cents: 35_000, last_success_at: Time.current
    )
  end

  test "shows public product details and confirmed stock and price history" do
    @listing.update!(image_url: "https://images.example.test/popular.jpg")
    @listing.change_events.create!(
      kind: "RESTOCKED", previous_value: { "value" => "out_of_stock" },
      current_value: { "value" => "in_stock", "parser_version" => ListingState::PARSER_VERSION }, occurred_at: 2.days.ago
    )
    @listing.change_events.create!(
      kind: "PRICE_CHANGED", previous_value: { "value" => 40_000 },
      current_value: { "value" => 35_000, "parser_version" => ListingState::PARSER_VERSION }, occurred_at: 1.day.ago
    )
    @listing.change_events.create!(kind: "SOLD_OUT", occurred_at: 3.days.ago)

    assert_difference -> { @listing.reload.clicks_count }, 1 do
      get listing_path(@listing)
    end

    assert_response :success
    assert_select "h1", text: @listing.title
    assert_select "img.product-image[src='https://images.example.test/popular.jpg']"
    assert_select ".detail-copy .new-badge", text: "NEW"
    assert_select "[data-like-notice][hidden]"
    assert_select "button[data-like-login-required][aria-pressed='false']"
    assert_select ".like-explanation", text: /재입고와 가격 변동을 모두 즉시.*인증한 이메일/
    assert_select "a[href='#{@listing.canonical_url}'][target='_blank']", text: "판매처에서 구매하기"
    assert_select "[data-change-event='PRICE_CHANGED']", text: /40,000원.*35,000원/
    assert_select "[data-change-event='RESTOCKED']", text: /품절.*재고 있음/
    assert_select "[data-change-event='SOLD_OUT']", count: 0
    assert_select "[data-detail-view-count][data-listing-id='#{@listing.id}'][data-view-count='1']", text: "조회수 1"
  end

  test "requires a verified login and connects likes to email subscriptions" do
    post like_listing_path(@listing)
    assert_redirected_to root_path
    assert_equal 0, ListingLike.count

    post development_login_path
    get listing_path(@listing)
    assert_select "button[data-like-url='#{like_listing_path(@listing)}'][aria-pressed='false']"

    assert_difference "ListingLike.count", 1 do
      post like_listing_path(@listing)
    end
    assert_response :success
    assert_equal({ "liked" => true, "count" => 1 }, response.parsed_body)
    user = User.find_by!(provider: "development", uid: "local")
    assert user.subscriptions.exists?(listing: @listing, variant_external_id: "", active: true)
    get listing_path(@listing)
    assert_select "button[data-like-url='#{like_listing_path(@listing)}'][aria-pressed='true']"

    restock = @listing.change_events.create!(kind: "RESTOCKED", occurred_at: Time.current)
    assert_difference "MailDelivery.count", 1 do
      ImmediateNotificationBuilder.call(restock)
    end
    price_change = @listing.change_events.create!(kind: "PRICE_CHANGED", occurred_at: Time.current)
    assert_difference "MailDelivery.count", 1 do
      ImmediateNotificationBuilder.call(price_change)
    end
    assert_equal [ "event", "event" ], user.mail_deliveries.order(:id).pluck(:kind)

    assert_difference "ListingLike.count", -1 do
      post like_listing_path(@listing)
    end
    assert_equal({ "liked" => false, "count" => 0 }, response.parsed_body)
    assert_not user.subscriptions.exists?(listing: @listing, variant_external_id: "")
  end

  test "renders filter and sorting data for the preloaded catalog" do
    restocked_at = 2.days.ago
    @listing.update!(clicks_count: 7, created_at: 3.days.ago)
    old_listing = @site.listings.create!(
      external_id: "old", canonical_url: "https://catalog.example.test/old",
      title: "기존 만년필", status: "in_stock", base_price_cents: 20_000,
      last_success_at: Time.current, created_at: 31.days.ago
    )
    @listing.change_events.create!(kind: "RESTOCKED", current_value: { "parser_version" => ListingState::PARSER_VERSION }, occurred_at: restocked_at)

    get root_path

    assert_response :success
    assert_select "[data-catalog-controls]"
    assert_select "select[data-filter-site] option[value='#{@site.id}']", text: @site.name
    assert_select "select[data-filter-status] option[value='in_stock']", text: "재고 있음"
    assert_select "input[data-filter-min-price][type='number']"
    assert_select "input[data-filter-max-price][type='number']"
    assert_select "input[data-filter-restocked][type='checkbox']"
    assert_select "select[data-catalog-sort] option[value='popularity']", text: "인기도순"
    assert_select "select[data-catalog-sort] option[value='newest']", text: "최신 등록순"
    assert_select "select[data-catalog-sort] option[value='likes']", text: "좋아요순"
    assert_select "select[data-catalog-sort] option[value='price_asc']", text: "가격 낮은순"
    assert_select "select[data-catalog-sort] option[value='price_desc']", text: "가격 높은순"
    assert_select "select[data-catalog-sort] option[value='restocked']", text: "최근 재입고순"
    assert_select "[data-catalog-card][data-site-id='#{@site.id}'][data-status='in_stock'][data-price='35000'][data-clicks='7'][data-restocked-at='#{restocked_at.to_i}']"
    assert_select "[data-catalog-card][data-detail-url='#{listing_path(@listing)}']"
    assert_select "[data-listing-id='#{@listing.id}'] .new-badge", text: "NEW"
    assert_select "[data-listing-id='#{old_listing.id}'] .new-badge", count: 0
    assert_select "a[data-product-title='#{@listing.title}'][href='#{listing_path(@listing)}']"
    assert_select ".product-actions span.muted", text: "조회수 7"
    assert_select "[data-catalog-notice][hidden]"
    assert_select "button[data-like-login-required][aria-pressed='false']"
    assert_select "button[data-like-url]", count: 0
    assert_select "[data-track-click]", count: 0

    post development_login_path
    get root_path
    assert_select "button[data-like-url='#{like_listing_path(@listing)}'][aria-pressed='false']"
  end
end
