class Site < ApplicationRecord
  has_many :listings, dependent: :destroy

  validates :code, :name, :base_url, :parser_kind, presence: true
  validates :code, uniqueness: true

  scope :available, -> { where(enabled: true).where("backoff_until IS NULL OR backoff_until <= ?", Time.current) }
end
