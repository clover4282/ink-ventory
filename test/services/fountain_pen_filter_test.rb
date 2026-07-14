require "test_helper"

class FountainPenFilterTest < ActiveSupport::TestCase
  test "keeps fountain pens and fountain pen sets" do
    assert FountainPenFilter.match?("세일러 만년필")
    assert FountainPenFilter.match?("세일러 만년필+잉크 세트")
  end

  test "rejects accessories and other writing instruments" do
    assert_not FountainPenFilter.match?("만년필용 잉크")
    assert_not FountainPenFilter.match?("파이롯트 병잉크 30ml 만년필용")
    assert_not FountainPenFilter.match?("크로스 잉크 카트리지 (만년필 전용)")
    assert_not FountainPenFilter.match?("무료증정 만년필 구호용품")
    assert_not FountainPenFilter.match?("카웨코 컨버터", trusted_category: true)
    assert_not FountainPenFilter.match?("카웨코 딥펜", trusted_category: true)
    assert_not FountainPenFilter.match?("라미 볼펜", trusted_category: true)
  end

  test "trusts an unambiguous category for fountain pen model names" do
    assert FountainPenFilter.match?("세일러 프로기어 슬림 14K 문라이트", trusted_category: true)
    assert_not FountainPenFilter.match?("세일러 프로기어 슬림 14K 문라이트")
  end
end
