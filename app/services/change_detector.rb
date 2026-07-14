class ChangeDetector
  CONFIRMATION_DELAY = 1.minute
  POLL_INTERVAL = 10.minutes

  def self.observe(listing, state, at: Time.current)
    new(listing, state, at: at).observe
  end

  def initialize(listing, state, at:)
    @listing = listing
    @state = state
    @state_hash = state.as_json
    @at = at
  end

  def observe
    events = []
    @listing.with_lock do
      @listing.observations.create!(state: @state_hash, observed_at: @at)
      if @listing.current_state.blank?
        apply_state!
      elsif @listing.current_state == @state_hash
        @listing.update!(pending_state: nil, pending_seen_at: nil, next_check_at: @at + POLL_INTERVAL)
      elsif @listing.pending_state == @state_hash && @listing.pending_seen_at <= @at - CONFIRMATION_DELAY
        previous = @listing.current_state.deep_dup
        apply_state!
        events = create_events!(previous, @state_hash)
      else
        @listing.update!(pending_state: @state_hash, pending_seen_at: @at, next_check_at: @at + 2.minutes)
      end
    end

    events.each { |event| ImmediateNotificationBuilder.call(event) }
    events
  end

  private
    def apply_state!
      @listing.update!(
        title: @state.title, currency: @state.currency, base_price_cents: @state.base_price_cents,
        status: @state.availability, current_state: @state_hash, pending_state: nil, pending_seen_at: nil,
        last_checked_at: @at, last_success_at: @at, next_check_at: @at + POLL_INTERVAL,
        consecutive_errors: 0
      )
      @listing.variants.delete_all
    end

    def create_events!(previous, current)
      events = []
      events.concat(availability_events(previous, current))
      events << event!("PRICE_CHANGED", "", previous["base_price_cents"], current["base_price_cents"]) if changed_price?(previous["base_price_cents"], current["base_price_cents"])
      evaluate_targets!(previous, current, events)
      events
    end

    def availability_events(previous, current)
      before = previous["availability"]
      after = current["availability"]
      return [] if before == after
      return [ event!("RESTOCKED", "", before, after) ] if before != "in_stock" && after == "in_stock"
      return [ event!("SOLD_OUT", "", before, after) ] if before == "in_stock" && after == "out_of_stock"
      []
    end

    def evaluate_targets!(previous, current, events)
      @listing.subscriptions.where(active: true).where.not(target_price_cents: nil).find_each do |subscription|
        before = previous["base_price_cents"]
        after = current["base_price_cents"]
        next unless after
        if after > subscription.target_price_cents
          subscription.update!(target_armed: true) unless subscription.target_armed?
        elsif subscription.target_armed? && before && before > subscription.target_price_cents
          target_event = event!(
            "TARGET_REACHED", "", before, after,
            "subscription_id" => subscription.id, "target_price_cents" => subscription.target_price_cents
          )
          subscription.update!(target_armed: false)
          events << target_event
        end
      end
    end

    def changed_price?(before, after)
      !before.nil? && !after.nil? && before != after
    end

    def event!(kind, external_id, before, after, extra = {})
      @listing.change_events.create!(
        kind: kind, variant_external_id: external_id, previous_value: { "value" => before },
        current_value: { "value" => after }.merge(extra), occurred_at: @at
      )
    end
end
