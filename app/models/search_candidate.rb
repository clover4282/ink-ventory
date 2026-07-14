class SearchCandidate < ApplicationRecord
  belongs_to :search_query
  belongs_to :listing
  validates :listing_id, uniqueness: { scope: :search_query_id }
end
