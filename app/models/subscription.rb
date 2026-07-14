class Subscription < ApplicationRecord
  belongs_to :watch_group
  belongs_to :listing

  validates :variant_external_id, uniqueness: { scope: %i[watch_group_id listing_id] }
  validates :target_price_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0, allow_nil: true }

  delegate :user, to: :watch_group

  def selected_variant
    return if variant_external_id.blank?
    listing.variants.find_by(external_id: variant_external_id)
  end
end
