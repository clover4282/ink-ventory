class Subscription < ApplicationRecord
  MAX_ACTIVE_PER_USER = 10
  LIMIT_MESSAGE = "관심 상품은 최대 10개까지 등록할 수 있습니다."

  belongs_to :watch_group
  belongs_to :listing

  validates :variant_external_id, uniqueness: { scope: %i[watch_group_id listing_id] }
  validate :active_interest_limit, if: -> { active? && (new_record? || will_save_change_to_active?) }

  delegate :user, to: :watch_group

  def selected_variant
    return if variant_external_id.blank?
    listing.variants.find_by(external_id: variant_external_id)
  end

  private
    def active_interest_limit
      errors.add(:base, LIMIT_MESSAGE) if watch_group.user.subscriptions.where(active: true).where.not(id: id).count >= MAX_ACTIVE_PER_USER
    end
end
