class SearchWatch < ApplicationRecord
  belongs_to :user
  belongs_to :search_query
  validates :search_query_id, uniqueness: { scope: :user_id }
end
