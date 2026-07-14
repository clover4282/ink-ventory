class Variant < ApplicationRecord
  belongs_to :listing

  validates :external_id, :name, :availability, presence: true
  validates :external_id, uniqueness: { scope: :listing_id }
end
