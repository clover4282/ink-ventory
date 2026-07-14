class EventReceipt < ApplicationRecord
  belongs_to :user
  belongs_to :change_event
  belongs_to :mail_delivery, optional: true

  validates :change_event_id, uniqueness: { scope: %i[user_id channel] }
end
