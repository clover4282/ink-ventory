class NotificationAddressesController < ApplicationController
  before_action :require_authentication, except: %i[verify unsubscribe]

  def edit
    @notification_address = current_user.notification_address || current_user.build_notification_address
  end

  def update
    address = current_user.notification_address || current_user.build_notification_address
    new_email = params.require(:notification_address).permit(:email)[:email].to_s.strip.downcase
    address.reset_verification! if address.email != new_email
    address.email = new_email
    address.save!
    NotificationOutbox.enqueue(
      user: current_user, kind: "verification", dedupe_key: "verify:#{address.id}:#{address.verification_token}", metadata: {}
    )
    redirect_to edit_notification_address_path, notice: "인증 메일을 보냈습니다. 메일함을 확인해 주세요."
  rescue ActiveRecord::RecordInvalid => error
    @notification_address = error.record
    flash.now[:alert] = "올바른 이메일 주소를 입력해 주세요."
    render :edit, status: :unprocessable_entity
  end

  def verify
    address = NotificationAddress.find_by!(verification_token: params[:token])
    address.verify!
    redirect_to root_path, notice: "알림 이메일 인증이 완료되었습니다."
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path, alert: "유효하지 않거나 이미 사용된 인증 링크입니다."
  end

  def unsubscribe
    address = NotificationAddress.find_by!(unsubscribe_token: params[:token])
    address.update!(notifications_enabled: false)
    redirect_to root_path, notice: "모든 이메일 알림을 중지했습니다."
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path, alert: "유효하지 않은 수신 중지 링크입니다."
  end
end
