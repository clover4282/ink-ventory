require "test_helper"

class StoreParserTest < ActiveSupport::TestCase
  test "parses fixtures for all four supported stores" do
    expectations = {
      "bestpen_product.html" => [ "makeshop", "베스트펜 테스트 만년필", 30_000, 1 ],
      "pengalleria_product.html" => [ "makeshop", "펜갤러리아 테스트 만년필", 51_000, 2 ],
      "blueblack_product.html" => [ "cafe24", "블루블랙 테스트 만년필", 240_000, 1 ],
      "penlog_product.html" => [ "cafe24", "펜로그 테스트 만년필", 146_250, 1 ]
    }

    expectations.each do |filename, (parser_kind, title, price, variant_count)|
      html = Rails.root.join("test/fixtures/html", filename).read
      state = StoreParser.call(html, parser_kind: parser_kind)
      assert_equal [ title, price, variant_count ], [ state.title, state.base_price_cents, state.variants.size ]
    end
  end

  test "parses json ld variants without using hidden stock" do
    html = <<~HTML
      <html><head>
        <script type="application/ld+json">
          {"@type":"Product","name":"라미 사파리","offers":{"@type":"AggregateOffer","lowPrice":"32000","offers":[
            {"sku":"EF-BLUE","name":"블루 EF","price":"32000","priceCurrency":"KRW","availability":"https://schema.org/InStock"},
            {"sku":"F-BLUE","name":"블루 F","price":"33000","priceCurrency":"KRW","availability":"https://schema.org/OutOfStock"}
          ]}}
        </script>
        <script>window.stock_number = 99;</script>
      </head></html>
    HTML

    state = StoreParser.call(html, parser_kind: "cafe24")

    assert_equal "라미 사파리", state.title
    assert_equal 32_000, state.base_price_cents
    assert_equal %w[in_stock out_of_stock], state.variants.map(&:availability)
    assert_nil state.variants.first.visible_quantity
  end

  test "parses product offers supplied as a json ld array" do
    html = <<~HTML
      <script type="application/ld+json">
        {"@type":"Product","name":"배열형 만년필","offers":[
          {"price":"25000","priceCurrency":"KRW","availability":"https://schema.org/InStock"},
          {"price":"27000","priceCurrency":"KRW","availability":"https://schema.org/OutOfStock"}
        ]}
      </script>
    HTML

    state = StoreParser.call(html, parser_kind: "cafe24")

    assert_equal 25_000, state.base_price_cents
    assert_equal "in_stock", state.availability
    assert_equal %w[in_stock out_of_stock], state.variants.map(&:availability)
  end

  test "parses visible makeshop options and only explicit visible quantities" do
    html = <<~HTML
      <html><head><meta property="og:title" content="카웨코 스포츠"><meta property="product:price:amount" content="45,000"></head>
      <body>
        <select id="navigation"><option value="brand-a">브랜드 A</option><option value="brand-b">브랜드 B</option></select>
        <select class="basic_option"><option value="">옵션 선택</option><option value="ef">EF (재고 3개)</option><option value="f" disabled>F [품절]</option></select>
      </body></html>
    HTML

    state = StoreParser.call(html, parser_kind: "makeshop")

    assert_equal 45_000, state.base_price_cents
    assert_equal 3, state.variants.first.visible_quantity
    assert_equal "out_of_stock", state.variants.last.availability
  end

  test "keeps makeshop options that reuse the same value" do
    html = <<~HTML
      <html><head><meta property="og:title" content="다단 옵션 만년필"><meta property="product:price:amount" content="45,000"></head>
      <body>
        <select class="basic_option"><option value="0">베이직 라인</option><option value="1">투명 라인</option></select>
        <select class="basic_option"><option value="0">라이트 블루 EF</option><option value="1">옐로우 EF</option></select>
      </body></html>
    HTML

    state = StoreParser.call(html, parser_kind: "makeshop")

    assert_equal %w[0 1 0--2 1--2], state.variants.map(&:external_id)
  end

  test "raises on an unrecognizable response instead of treating it as sold out" do
    assert_raises(StoreParser::ParseError) { StoreParser.call("<html><body>접근 오류</body></html>", parser_kind: "cafe24") }
  end

  test "prefers a cafe24 product image and normalizes it to https" do
    html = <<~HTML
      <html><head><meta property="og:title" content="테스트 펜"><meta property="og:image" content="http://example.com/store-logo.jpg"></head>
      <body><img class="BigImage" src="//cdn.example.com/product.jpg"></body></html>
    HTML

    state = StoreParser.call(html, parser_kind: "cafe24", page_url: "https://shop.example.com/product/1")

    assert_equal "https://cdn.example.com/product.jpg", state.image_url
  end

  test "uses a makeshop detail image when og image is absent" do
    html = <<~HTML
      <html><head><meta property="og:title" content="테스트 펜"></head>
      <body><img class="detail_image" src="/shopimages/product.jpg"></body></html>
    HTML

    state = StoreParser.call(html, parser_kind: "makeshop", page_url: "https://shop.example.com/product/1")

    assert_equal "https://shop.example.com/shopimages/product.jpg", state.image_url
  end

  test "prefers the visible makeshop sale price and purchase state" do
    html = <<~HTML
      <html><head><meta property="og:title" content="할인 펜"></head><body>
        <table><tr><td class="price">15,000원</td><td class="price sell_price">13,500원</td></tr></table>
        <div class="prd-btns"><a class="btn_buy">바로구매</a></div>
      </body></html>
    HTML

    state = StoreParser.call(html, parser_kind: "makeshop")

    assert_equal 13_500, state.base_price_cents
    assert_equal "in_stock", state.availability
  end

  test "ignores hidden cafe24 sold out controls when purchase is available" do
    html = <<~HTML
      <html><head><meta property="og:title" content="판매 중인 펜"><meta property="product:price:amount" content="3000"></head><body>
        <div class="xans-product-action productAction">
          <span class="btnSubmit disabled displaynone">품절</span>
          <a>구매하기</a>
        </div>
      </body></html>
    HTML

    state = StoreParser.call(html, parser_kind: "cafe24")

    assert_equal "in_stock", state.availability
  end

  test "ignores cafe24 additional product options" do
    html = <<~HTML
      <html><head><meta property="og:title" content="옵션 만년필"><meta property="product:price:amount" content="30000"></head><body>
        <div class="xans-product-option">
          <select id="product_option_id1"><option value="">선택</option><option value="EF">EF</option></select>
          <select id="addproduct_option_id_10_1"><option value="">선택</option><option value="블랙">사은품 잉크 블랙</option></select>
        </div>
      </body></html>
    HTML

    state = StoreParser.call(html, parser_kind: "cafe24")

    assert_equal [ "EF" ], state.variants.map(&:name)
  end
end
