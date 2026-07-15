require "test_helper"

class EmailLoginTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    ActionMailer::Base.deliveries.clear
    clear_enqueued_jobs
  end

  test "shows email code login instead of social login" do
    get root_path

    assert_response :success
    assert_select "form[action='#{login_path}'] input[type='email'][name='email']"
    assert_select "form[action='/auth/google_oauth2']", count: 0
    assert_select "form[action='/auth/kakao']", count: 0
  end

  test "prioritizes login email separately from crawler jobs" do
    assert_equal :mailers, NotificationMailer.deliver_later_queue_name

    config = YAML.safe_load(ERB.new(Rails.root.join("config/queue.yml").read).result, aliases: true)
    worker_queues = config.fetch("test").fetch("workers").pluck("queues")
    assert_includes worker_queues, %w[mailers default solid_queue_recurring]
    assert_includes worker_queues, %w[crawlers]
    assert_not_includes worker_queues, "*"
  end

  test "emails a code and signs in with a verified notification address" do
    perform_enqueued_jobs do
      post login_path, params: { email: " User@Example.com " }
    end

    assert_redirected_to root_path
    assert_equal "user@example.com", LoginChallenge.find_by!(email: "user@example.com").email
    mail = ActionMailer::Base.deliveries.last
    assert_equal [ "user@example.com" ], mail.to
    code = mail.text_part.body.decoded[/\b\d{6}\b/]
    assert code

    post verify_login_path, params: { email: "user@example.com", code: code }

    assert_redirected_to root_path
    assert_match(/expires=/i, response.headers["Set-Cookie"])
    follow_redirect!
    user = User.find_by!(email: "user@example.com")
    assert_predicate user, :verified_for_notifications?
    assert_equal "user@example.com", user.notification_address.email
    assert_not LoginChallenge.exists?(email: "user@example.com")
    assert_includes response.body, "user님의 만년필 찾기"
  end

  test "expires codes and locks a challenge for one hour after five failed attempts" do
    post login_path, params: { email: "retry@example.com" }
    challenge = LoginChallenge.find_by!(email: "retry@example.com")
    challenge.update!(code_digest: "0" * 64)

    4.times do
      post verify_login_path, params: { email: challenge.email, code: "000000" }
      assert LoginChallenge.exists?(challenge.id)
    end
    challenge.update!(sent_at: 2.minutes.ago)
    post login_path, params: { email: challenge.email }
    assert_equal 4, challenge.reload.attempts
    challenge.update!(code_digest: "0" * 64)

    post verify_login_path, params: { email: challenge.email, code: "000000" }
    assert LoginChallenge.exists?(challenge.id)
    assert_in_delta 1.hour.from_now, challenge.reload.locked_until, 2.seconds

    assert_no_enqueued_emails do
      post login_path, params: { email: challenge.email }
    end
    assert_equal "인증번호를 5회 잘못 입력해 로그인이 잠겼습니다. 1시간 후 다시 시도해 주세요.", flash[:alert]

    challenge.update!(locked_until: 1.minute.ago, sent_at: 2.hours.ago)
    assert_enqueued_emails 1 do
      post login_path, params: { email: challenge.email }
    end
    assert_nil challenge.reload.locked_until
    assert_equal 0, challenge.attempts

    post login_path, params: { email: "expired@example.com" }
    expired = LoginChallenge.find_by!(email: "expired@example.com")
    expired.update!(expires_at: 1.minute.ago)
    post verify_login_path, params: { email: expired.email, code: "000000" }
    assert_not LoginChallenge.exists?(expired.id)
    assert_equal 0, User.where(email: %w[retry@example.com expired@example.com]).count
  end

  test "waits sixty seconds before resending a code" do
    post login_path, params: { email: "wait@example.com" }

    assert_no_enqueued_emails do
      post login_path, params: { email: "wait@example.com" }
    end
    assert_redirected_to root_path
    assert_equal "인증번호는 60초 후 다시 받을 수 있습니다.", flash[:alert]
  end
end
