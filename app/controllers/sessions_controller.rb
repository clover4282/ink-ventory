class SessionsController < ApplicationController
  def create
    user = User.from_omniauth(request.env.fetch("omniauth.auth"))
    reset_session
    session[:user_id] = user.id
    redirect_to root_path, notice: "#{user.name}님, 환영합니다."
  rescue KeyError, ActiveRecord::RecordInvalid => error
    Rails.logger.warn("social login failed: #{error.message}")
    redirect_to root_path, alert: "소셜 로그인에 실패했습니다."
  end

  def failure
    redirect_to root_path, alert: "소셜 로그인이 취소되었거나 실패했습니다."
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
end
