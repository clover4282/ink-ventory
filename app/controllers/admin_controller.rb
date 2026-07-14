class AdminController < ApplicationController
  before_action :require_authentication
  before_action :require_admin

  def index
    @sites = Site.order(:id)
    @failed_listings = Listing.where("consecutive_errors > 0").includes(:site).order(consecutive_errors: :desc).limit(50)
    @mail_deliveries = MailDelivery.order(created_at: :desc).limit(50)
  end

  def update_site
    site = Site.find(params[:id])
    site.update!(enabled: params[:enabled] == "1", backoff_until: nil)
    redirect_to admin_path, notice: "사이트 수집 설정을 저장했습니다."
  end
end
