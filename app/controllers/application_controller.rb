class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  helper_method :current_user

  private
    def current_user
      @current_user ||= User.find_by(id: session[:user_id])
    end

    def require_authentication
      redirect_to root_path, alert: "로그인이 필요합니다." unless current_user
    end

    def require_verified_email
      return if current_user&.verified_for_notifications?
      redirect_to edit_notification_address_path, alert: "관심 상품을 등록하려면 알림 이메일을 인증해 주세요."
    end

    def require_admin
      redirect_to root_path, alert: "관리자만 접근할 수 있습니다." unless current_user&.admin?
    end
end
