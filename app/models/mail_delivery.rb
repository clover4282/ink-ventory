class MailDelivery < ApplicationRecord
  STATUSES = %w[pending processing sent failed canceled].freeze

  belongs_to :user, optional: true
  has_many :event_receipts, dependent: :nullify

  validates :kind, :recipient, :dedupe_key, :scheduled_at, presence: true
  validates :dedupe_key, uniqueness: true
  validates :status, inclusion: { in: STATUSES }

  scope :due, -> { where(status: %w[pending failed]).where("scheduled_at <= ?", Time.current) }
end
