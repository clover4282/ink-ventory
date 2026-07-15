require "test_helper"

class SubscriptionTest < ActiveSupport::TestCase
  test "counts only active interests toward the ten item limit" do
    user = User.create!(provider: "test", uid: SecureRandom.uuid)
    group = user.watch_groups.create!(name: "관심 상품")
    site = Site.create!(code: "limit", name: "제한 테스트", base_url: "https://limit.example.test", parser_kind: "cafe24")
    listings = 11.times.map do |index|
      site.listings.create!(external_id: index.to_s, canonical_url: "https://limit.example.test/#{index}")
    end
    listings.first(10).each { |listing| group.subscriptions.create!(listing: listing) }
    paused = group.subscriptions.create!(listing: listings.last, active: false)

    assert_not paused.update(active: true)
    assert_includes paused.errors[:base], "관심 상품은 최대 10개까지 등록할 수 있습니다."

    group.subscriptions.where(active: true).first.update!(active: false)
    assert paused.update(active: true)
  end
end
