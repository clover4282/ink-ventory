class ListingsController < ApplicationController
  before_action :require_authentication
  before_action :require_verified_email

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
    redirect_to root_path, notice: "관심 상품을 등록했습니다. 첫 확인 뒤 상태가 표시됩니다."
  rescue SiteRegistry::UnsupportedUrl => error
    redirect_to root_path, alert: error.message
  end
end
