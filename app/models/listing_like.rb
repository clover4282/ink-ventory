class ListingLike < ApplicationRecord
  belongs_to :listing, counter_cache: :likes_count
  belongs_to :user

  validates :listing_id, uniqueness: { scope: :user_id }
end
