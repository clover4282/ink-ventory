class ChangesController < ApplicationController
  def index
    @change_events = ChangeEvent.versioned
      .where(kind: ChangeEvent::IMMEDIATE_KINDS)
      .includes(listing: :site)
      .order(occurred_at: :desc)
      .limit(100)
  end
end
