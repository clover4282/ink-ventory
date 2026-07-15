class ListingsController < ApplicationController
  before_action :require_authentication, only: %i[create like]
  before_action :require_verified_email, only: %i[create like]

  def show
    @listing = Listing.includes(:site).find(params[:id])
    @listing.increment!(:clicks_count)
    @liked = current_user ? @listing.listing_likes.exists?(user: current_user) : false
    @change_events = @listing.change_events.versioned.where(kind: %w[RESTOCKED SOLD_OUT PRICE_CHANGED]).order(occurred_at: :desc)
  end

  def create
    resolved = SiteRegistry.resolve(params.require(:url))
    SiteRegistry.ensure_sites!
    site = Site.find_by!(code: resolved.code)
    listing = Listing.find_or_create_by!(canonical_url: resolved.canonical_url) do |record|
      record.site = site
      record.external_id = resolved.external_id
      record.next_check_at = Time.current
    end
    group = current_user.watch_groups.first_or_create!(name: "관심 상품")
    group.subscriptions.find_or_create_by!(listing: listing, variant_external_id: "")
    CollectListingJob.perform_later(listing.id) if listing.current_state.blank?
    redirect_to subscriptions_path, notice: "관심 상품을 등록했습니다. 첫 확인 뒤 상태가 표시됩니다."
  rescue ActiveRecord::RecordInvalid => error
    redirect_to root_path, alert: error.record.errors.full_messages.first
  rescue SiteRegistry::UnsupportedUrl => error
    redirect_to root_path, alert: error.message
  end

  def like
    listing = Listing.find(params[:id])
    group = current_user.watch_groups.first_or_create!(name: "관심 상품")
    like = listing.listing_likes.find_by(user: current_user)

    ListingLike.transaction do
      if like
        like.destroy!
        group.subscriptions.find_by(listing: listing, variant_external_id: "")&.destroy!
      else
        listing.listing_likes.create!(user: current_user)
        subscription = group.subscriptions.find_or_initialize_by(listing: listing, variant_external_id: "")
        subscription.update!(active: true, notify_restock: true)
      end
    end

    render json: { liked: like.nil?, count: listing.reload.likes_count }
  rescue ActiveRecord::RecordInvalid => error
    render json: { error: error.record.errors.full_messages.first }, status: :unprocessable_entity
  end
end
