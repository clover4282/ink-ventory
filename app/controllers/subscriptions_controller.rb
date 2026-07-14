class SubscriptionsController < ApplicationController
  before_action :require_authentication, except: :unsubscribe
  before_action :require_verified_email, only: :create
  before_action :set_subscription, except: :unsubscribe

  def create
    listing = Listing.find(params.require(:listing_id))
    group = current_user.watch_groups.first_or_create!(name: "관심 상품")
    group.subscriptions.find_or_create_by!(listing: listing, variant_external_id: "")
    redirect_to root_path, notice: "관심 상품에 추가했습니다."
  end

  def update
    target = params.dig(:subscription, :target_price).to_s.delete(",").presence&.to_i
    @subscription.update!(
      variant_external_id: "",
      target_price_cents: target, active: params.dig(:subscription, :active) == "1",
      target_armed: true
    )
    redirect_to root_path, notice: "알림 설정을 저장했습니다."
  end

  def destroy
    current_user.listing_likes.find_by(listing_id: @subscription.listing_id)&.destroy! if @subscription.variant_external_id.blank?
    @subscription.destroy!
    redirect_to root_path, notice: "관심 상품을 삭제했습니다."
  end

  def unsubscribe
    address = NotificationAddress.find_by!(unsubscribe_token: params[:token])
    subscription = address.user.subscriptions.find(params[:id])
    subscription.update!(active: false)
    redirect_to root_path, notice: "이 상품의 알림을 중지했습니다."
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path, alert: "유효하지 않은 구독 해제 링크입니다."
  end

  private
    def set_subscription
      @subscription = current_user.subscriptions.find(params[:id]) if params[:id]
    end
end
