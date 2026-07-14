class WatchGroup < ApplicationRecord
  belongs_to :user
  has_many :subscriptions, dependent: :destroy

  validates :name, presence: true
end
