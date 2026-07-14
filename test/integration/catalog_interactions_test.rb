require "test_helper"

class CatalogInteractionsTest < ActionDispatch::IntegrationTest
  setup do
    @site = Site.create!(code: "catalog-test", name: "카탈로그 테스트", base_url: "https://catalog.example.test", parser_kind: "cafe24")
    @listing = @site.listings.create!(
      external_id: "popular", canonical_url: "https://catalog.example.test/popular",
      title: "인기 만년필", status: "in_stock", base_price_cents: 35_000, last_success_at: Time.current
    )
  end

  test "records public product clicks" do
    assert_difference -> { @listing.reload.clicks_count }, 1 do
      post click_listing_path(@listing)
    end

    assert_response :success
    assert_equal 1, response.parsed_body["count"]
  end

  test "requires a verified login and connects likes to email subscriptions" do
    post like_listing_path(@listing)
    assert_redirected_to root_path
    assert_equal 0, ListingLike.count

    post development_login_path
    assert_difference "ListingLike.count", 1 do
      post like_listing_path(@listing)
    end
    assert_response :success
    assert_equal({ "liked" => true, "count" => 1 }, response.parsed_body)
    user = User.find_by!(provider: "development", uid: "local")
    assert user.subscriptions.exists?(listing: @listing, variant_external_id: "", active: true)

    restock = @listing.change_events.create!(kind: "RESTOCKED", occurred_at: Time.current)
    assert_difference "MailDelivery.count", 1 do
      ImmediateNotificationBuilder.call(restock)
    end
    price_change = @listing.change_events.create!(kind: "PRICE_CHANGED", occurred_at: Time.current)
    assert_difference "MailDelivery.count", 1 do
      DigestBuilder.call(user)
    end
    assert_equal [ "event", "digest" ], user.mail_deliveries.order(:id).pluck(:kind)

    assert_difference "ListingLike.count", -1 do
      post like_listing_path(@listing)
    end
    assert_equal({ "liked" => false, "count" => 0 }, response.parsed_body)
    assert_not user.subscriptions.exists?(listing: @listing, variant_external_id: "")
  end

  test "renders filter and sorting data for the preloaded catalog" do
    restocked_at = 2.days.ago
    @listing.update!(clicks_count: 7, created_at: 3.days.ago)
    @listing.change_events.create!(kind: "RESTOCKED", occurred_at: restocked_at)

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
    assert_select ".product-actions span.muted", text: "조회수 7"
    assert_select "[data-catalog-notice][hidden]"
    assert_select "button[data-like-login-required][aria-pressed='false']"
    assert_select "button[data-like-url]", count: 0
    assert_select "a[data-track-click='#{click_listing_path(@listing)}']", minimum: 1

    post development_login_path
    get root_path
    assert_select "button[data-like-url='#{like_listing_path(@listing)}'][aria-pressed='false']"
  end
end
