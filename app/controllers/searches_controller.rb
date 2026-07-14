class SearchesController < ApplicationController
  before_action :require_authentication
  before_action :require_verified_email

  def create
    @search_query = ProductSearch.call(query: params.require(:query), user: current_user)
    current_user.search_watches.find_or_create_by!(search_query: @search_query)
    redirect_to search_path(@search_query)
  rescue ProductSearch::RateLimited, ArgumentError => error
    redirect_to root_path, alert: error.message
  rescue HttpFetcher::Error => error
    Rails.logger.warn("product search failed: #{error.message}")
    redirect_to root_path, alert: "쇼핑몰 검색 중 오류가 발생했습니다. 잠시 후 다시 시도해 주세요."
  end

  def show
    @search_query = current_user.search_queries.find(params[:id])
    @candidates = @search_query.search_candidates.includes(listing: :site).order(first_seen_at: :desc)
  end
end
