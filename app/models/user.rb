class User < ApplicationRecord
  has_one :notification_address, dependent: :destroy
  has_many :watch_groups, dependent: :destroy
  has_many :subscriptions, through: :watch_groups
  has_many :search_watches, dependent: :destroy
  has_many :search_queries, through: :search_watches
  has_many :search_attempts, dependent: :destroy
  has_many :mail_deliveries, dependent: :destroy
  has_many :event_receipts, dependent: :destroy

  validates :provider, :uid, presence: true
  validates :uid, uniqueness: { scope: :provider }

  def self.from_omniauth(auth)
    user = find_or_initialize_by(provider: auth.provider, uid: auth.uid)
    user.name = auth.info.name.presence || auth.info.nickname.presence || "사용자"
    user.email = auth.info.email.presence
    user.admin = true if ENV.fetch("ADMIN_EMAILS", "").split(",").map(&:strip).include?(user.email)
    user.save!
    user.watch_groups.first_or_create!(name: "관심 상품")
    user
  end

  def verified_for_notifications?
    notification_address&.verified_at? && notification_address.notifications_enabled?
  end
end
