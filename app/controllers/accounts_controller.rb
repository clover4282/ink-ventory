class AccountsController < ApplicationController
  before_action :require_authentication

  def destroy
    current_user.destroy!
    reset_session
    redirect_to root_path, notice: "회원 탈퇴와 개인정보 삭제가 완료되었습니다."
  end
end
