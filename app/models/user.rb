class User < ApplicationRecord
  has_one :notification_address, dependent: :destroy
  has_many :watch_groups, dependent: :destroy
  has_many :subscriptions, through: :watch_groups
  has_many :search_watches, dependent: :destroy
  has_many :search_queries, through: :search_watches
  has_many :search_attempts, dependent: :destroy
  has_many :mail_deliveries, dependent: :destroy
  has_many :event_receipts, dependent: :destroy
  has_many :listing_likes, dependent: :destroy

  validates :provider, :uid, presence: true
  validates :uid, uniqueness: { scope: :provider }
  validates :email, uniqueness: { case_sensitive: false }, allow_blank: true

  def self.from_verified_email(email)
    email = LoginChallenge.normalize_email(email)
    user = NotificationAddress.find_by("LOWER(email) = ?", email)&.user || find_by("LOWER(email) = ?", email)
    user ||= new(provider: "email", uid: SecureRandom.uuid)

    transaction do
      user.email = email
      user.name = email.split("@").first if user.name.blank?
      user.admin = true if ENV.fetch("ADMIN_EMAILS", "").split(",").map { |value| value.strip.downcase }.include?(email)
      user.save!
      user.watch_groups.first_or_create!(name: "관심 상품")
      address = user.notification_address || user.build_notification_address
      address.email = email
      address.save!
      address.verify!
    end
    user
  end

  def verified_for_notifications?
    notification_address&.verified_at? && notification_address.notifications_enabled?
  end
end
