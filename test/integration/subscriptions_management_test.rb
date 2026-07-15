require "test_helper"

class SubscriptionsManagementTest < ActionDispatch::IntegrationTest
  setup do
    @site = Site.create!(code: "interests", name: "관심 테스트", base_url: "https://interests.example.test", parser_kind: "cafe24")
    @listing = @site.listings.create!(
      external_id: "pen", canonical_url: "https://interests.example.test/pen",
      title: "관리할 만년필", status: "in_stock", base_price_cents: 50_000, last_success_at: Time.current,
      image_url: "https://images.example.test/pen.jpg"
    )
  end

  test "requires login for the interests management page" do
    get subscriptions_path

    assert_redirected_to root_path
    assert_equal "로그인이 필요합니다.", flash[:alert]
  end

  test "manages interests and recent changes on a separate page" do
    post development_login_path
    user = User.find_by!(provider: "development", uid: "local")
    subscription = user.watch_groups.find_by!(name: "관심 상품").subscriptions.create!(listing: @listing, variant_external_id: "")
    @listing.change_events.create!(kind: "PRICE_CHANGED", occurred_at: Time.current)

    get subscriptions_path

    assert_response :success
    assert_select "h1", text: "관심 상품 관리"
    assert_select "[data-interest-count]", text: "1/10"
    assert_select ".site-nav a.active[href='#{subscriptions_path}'][aria-current='page']", text: "관심 상품"
    assert_select "img.product-image[src='#{@listing.image_url}']"
    assert_select "form[action='#{subscription_path(subscription)}']", count: 1
    assert_select "input[name='subscription[target_price]']", count: 0
    assert_select "input[name='subscription[active]']", count: 0
    assert_select "input[type='submit'][value='저장']", count: 0
    assert_select "form[action='#{subscription_path(subscription)}'] button", text: "삭제"
    assert_not_includes response.body, "목표 가격"
    assert_select "a[href='#{listing_path(@listing)}']", text: @listing.title
    assert_select "[data-recent-events]", text: /관리할 만년필/
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(subscription_path(subscription), method: :patch)
    end
  end
end
