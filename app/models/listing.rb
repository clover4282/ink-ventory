class Listing < ApplicationRecord
  belongs_to :site
  has_many :variants, dependent: :destroy
  has_many :observations, dependent: :destroy
  has_many :subscriptions, dependent: :destroy
  has_many :change_events, dependent: :destroy
  has_many :search_candidates, dependent: :destroy

  validates :external_id, :canonical_url, presence: true
  validates :canonical_url, uniqueness: true
  validates :external_id, uniqueness: { scope: :site_id }

  scope :due, -> { joins(:site).merge(Site.available).where("next_check_at IS NULL OR next_check_at <= ?", Time.current).order(Arel.sql("next_check_at NULLS FIRST")) }

  def display_price
    base_price_cents && ActiveSupport::NumberHelper.number_to_delimited(base_price_cents)
  end
end
