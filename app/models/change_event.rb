class ChangeEvent < ApplicationRecord
  KINDS = %w[RESTOCKED SOLD_OUT PRICE_CHANGED TARGET_REACHED VISIBLE_QUANTITY_CHANGED NEW_SEARCH_RESULT REMOVED].freeze
  IMMEDIATE_KINDS = %w[RESTOCKED PRICE_CHANGED TARGET_REACHED].freeze

  belongs_to :listing
  belongs_to :search_query, optional: true
  has_many :event_receipts, dependent: :destroy

  validates :kind, inclusion: { in: KINDS }
  validates :occurred_at, presence: true

  scope :digestible, -> { where.not(kind: "TARGET_REACHED") }
  scope :versioned, -> { where("json_extract(current_value, '$.parser_version') IS NOT NULL") }
end
