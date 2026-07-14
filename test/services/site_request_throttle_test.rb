require "test_helper"

class SiteRequestThrottleTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup { Site.where(code: "throttle-test").delete_all }
  teardown { Site.where(code: "throttle-test").delete_all }

  test "does not hold a database transaction while making a request" do
    site = Site.create!(code: "throttle-test", name: "테스트", base_url: "https://example.com", parser_kind: "makeshop", min_delay_seconds: 0)
    transaction_open = nil

    result = SiteRequestThrottle.call(site) do
      transaction_open = ApplicationRecord.connection.transaction_open?
      :response
    end

    assert_equal :response, result
    assert_not transaction_open
    assert site.reload.last_request_at
  end
end
