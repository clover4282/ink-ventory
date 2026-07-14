class SearchQuery < ApplicationRecord
  has_many :search_watches, dependent: :destroy
  has_many :users, through: :search_watches
  has_many :search_candidates, dependent: :destroy
  has_many :listings, through: :search_candidates
  has_many :change_events, dependent: :destroy

  before_validation :set_normalized_query
  validates :query, :normalized_query, presence: true
  validates :normalized_query, uniqueness: true

  scope :due, -> { where("next_search_at IS NULL OR next_search_at <= ?", Time.current) }

  def self.normalize(value)
    value.to_s.unicode_normalize(:nfc).squish.downcase
  end

  private
    def set_normalized_query
      self.normalized_query = self.class.normalize(query)
    end
end
