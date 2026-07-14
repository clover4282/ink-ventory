class Observation < ApplicationRecord
  belongs_to :listing
  validates :state, :observed_at, presence: true
end
