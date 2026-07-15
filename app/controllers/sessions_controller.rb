class SessionsController < ApplicationController
  rate_limit to: 10, within: 10.minutes, only: :create, with: :login_rate_limited

  def create
    email = LoginChallenge.normalize_email(params[:email])
    code = LoginChallenge.issue!(email)
    session[:login_email] = email
    NotificationMailer.login_code(email, code).deliver_later
    redirect_to root_path, notice: "이메일로 6자리 인증번호를 보냈습니다."
  rescue LoginChallenge::RecentlySent
    redirect_to root_path, alert: "인증번호는 60초 후 다시 받을 수 있습니다."
  rescue LoginChallenge::Locked
    redirect_to root_path, alert: "인증번호를 5회 잘못 입력해 로그인이 잠겼습니다. 1시간 후 다시 시도해 주세요."
  rescue ActiveRecord::RecordInvalid
    redirect_to root_path, alert: "올바른 이메일 주소를 입력해 주세요."
  end

  def verify
    email = LoginChallenge.normalize_email(params[:email])
    challenge = LoginChallenge.find_by(email: email)
    result = challenge&.verify(params[:code])
    if result == :locked
      redirect_to root_path, alert: "인증번호를 5회 잘못 입력해 로그인이 잠겼습니다. 1시간 후 다시 시도해 주세요."
      return
    end
    unless result == :verified
      redirect_to root_path, alert: "인증번호가 올바르지 않거나 만료되었습니다."
      return
    end

    user = User.from_verified_email(email)
    reset_session
    session[:user_id] = user.id
    redirect_to root_path, notice: "#{user.name}님, 로그인했습니다."
  rescue ActiveRecord::RecordInvalid => error
    Rails.logger.warn("email login failed: #{error.message}")
    redirect_to root_path, alert: "이메일 로그인에 실패했습니다."
  end

  def development
    user = User.find_or_initialize_by(provider: "development", uid: "local")
    user.update!(name: "개발자", email: "developer@example.test", admin: true)
    user.watch_groups.first_or_create!(name: "관심 상품")
    address = user.notification_address || user.build_notification_address
    address.update!(email: "developer@example.test", verified_at: Time.current, notifications_enabled: true)
    reset_session
    session[:user_id] = user.id
    redirect_to root_path, notice: "개발자 모드로 로그인했습니다."
  end

  def destroy
    reset_session
    redirect_to root_path, notice: "로그아웃했습니다."
  end

  private
    def login_rate_limited
      redirect_to root_path, alert: "인증번호 요청이 너무 많습니다. 잠시 후 다시 시도해 주세요."
    end
end
