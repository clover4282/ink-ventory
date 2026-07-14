require "test_helper"

class DevelopmentLoginTest < ActionDispatch::IntegrationTest
  test "signs in a verified local developer" do
    post development_login_path

    assert_redirected_to root_path
    follow_redirect!
    assert_response :success
    assert_includes response.body, "개발자님의 관심 상품"
    assert_not_includes response.body, "상품 URL 등록"
    assert_not_includes response.body, "제품명 통합 검색"

    user = User.find_by!(provider: "development", uid: "local")
    assert_predicate user, :admin?
    assert_predicate user, :verified_for_notifications?
  end

  test "shows recently crawled listings on the dashboard" do
    site = Site.create!(code: "home-store", name: "홈 테스트", base_url: "https://store.example.test", parser_kind: "cafe24")
    listing = site.listings.create!(
      external_id: "pen-1", canonical_url: "https://store.example.test/product/pen-1",
      title: "테스트 만년필", status: "in_stock", base_price_cents: 32_000, last_success_at: Time.current
    )
    listing.variants.create!(external_id: "ef", name: "EF촉", availability: "in_stock", effective_price_cents: 33_000)
    site.listings.create!(external_id: "pending", canonical_url: "https://store.example.test/product/pending", title: "수집 전 상품")

    post development_login_path
    follow_redirect!

    assert_includes response.body, "현재 수집 만년필 1개"
    assert_includes response.body, "테스트 만년필"
    assert_includes response.body, "EF촉"
    assert_not_includes response.body, "수집 전 상품"
    assert_select ".product-image-placeholder", text: "이미지 수집 중", count: 1
  end

  test "shows crawled listings without signing in" do
    site = Site.create!(code: "bestpen", name: "공개 테스트", base_url: "https://public.example.test", parser_kind: "cafe24")
    site.listings.create!(
      external_id: "public-pen", canonical_url: "https://public.example.test/product/public-pen",
      title: "공개 만년필", status: "out_of_stock", base_price_cents: 45_000, last_success_at: Time.current,
      image_url: "https://images.example.test/public-pen.jpg"
    )

    get root_path

    assert_response :success
    assert_includes response.body, "현재 수집 만년필 1개"
    assert_includes response.body, "공개 만년필"
    assert_select "img.product-image[src='https://images.example.test/public-pen.jpg'][loading='lazy']", count: 1
    assert_select "img.shop-logo", count: 1
    assert_select "form[data-auto-submit] input[name='q'][placeholder='만년필명 또는 판매처를 검색하세요']", count: 1
    assert_not_includes response.body, "상품 URL 등록"
  end

  test "filters the public catalog by product or store name" do
    bestpen = Site.create!(code: "bestpen", name: "베스트펜", base_url: "https://bestpen.example.test", parser_kind: "makeshop")
    galleria = Site.create!(code: "pengalleria", name: "펜갤러리아", base_url: "https://galleria.example.test", parser_kind: "makeshop")
    lamy = bestpen.listings.create!(external_id: "lamy", canonical_url: "https://bestpen.example.test/lamy", title: "라미 사파리 만년필", last_success_at: Time.current)
    kaweco = galleria.listings.create!(external_id: "kaweco", canonical_url: "https://galleria.example.test/kaweco", title: "카웨코 스포츠 만년필", last_success_at: Time.current)

    get root_path, params: { q: "라미" }

    assert_response :success
    assert_includes response.body, "검색 결과 1개"
    assert_includes response.body, "라미 사파리 만년필"
    assert_includes response.body, "카웨코 스포츠 만년필"
    assert_select "[data-catalog-card][data-listing-id='#{lamy.id}']:not([hidden])", count: 1
    assert_select "[data-catalog-card][data-listing-id='#{kaweco.id}'][hidden]", count: 1
    assert_select "input[name='q'][value='라미'][autofocus]", count: 1
    assert_select "[data-catalog-results]", count: 1

    get root_path, params: { q: "라미".unicode_normalize(:nfd) }
    assert_includes response.body, "검색 결과 1개"
    assert_select "input[name='q'][value='라미']", count: 1

    get root_path, params: { q: "펜갤러리아" }
    assert_includes response.body, "카웨코 스포츠 만년필"
  end
end
