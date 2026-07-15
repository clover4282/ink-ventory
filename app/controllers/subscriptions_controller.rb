class SubscriptionsController < ApplicationController
  before_action :require_authentication, except: :unsubscribe
  before_action :require_verified_email, only: :create
  before_action :set_subscription, except: %i[index unsubscribe]

  def index
    @subscriptions = current_user.subscriptions.includes(listing: :site).order(active: :desc, created_at: :desc)
    @active_subscription_count = @subscriptions.count(&:active?)
    @recent_events = ChangeEvent.where(listing_id: @subscriptions.map(&:listing_id)).includes(listing: :site).order(occurred_at: :desc).limit(20)
  end

  def create
    listing = Listing.find(params.require(:listing_id))
    group = current_user.watch_groups.first_or_create!(name: "관심 상품")
    group.subscriptions.find_or_create_by!(listing: listing, variant_external_id: "")
    redirect_to subscriptions_path, notice: "관심 상품에 추가했습니다."
  rescue ActiveRecord::RecordInvalid => error
    redirect_to subscriptions_path, alert: error.record.errors.full_messages.first
  end

  def destroy
    current_user.listing_likes.find_by(listing_id: @subscription.listing_id)&.destroy! if @subscription.variant_external_id.blank?
    @subscription.destroy!
    redirect_to subscriptions_path, notice: "관심 상품을 삭제했습니다."
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
