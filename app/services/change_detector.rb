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
      external_ids = @state.variants.map { |variant| variant.external_id.to_s }
      @listing.variants.where.not(external_id: external_ids).delete_all
      @state.variants.each do |variant|
        record = @listing.variants.find_or_initialize_by(external_id: variant.external_id.to_s)
        record.update!(
          name: variant.name, effective_price_cents: variant.price_cents,
          availability: variant.availability, visible_quantity: variant.visible_quantity
        )
      end
    end

    def create_events!(previous, current)
      events = []
      events.concat(availability_events(previous, current, ""))
      events << event!("PRICE_CHANGED", "", previous["base_price_cents"], current["base_price_cents"]) if changed_price?(previous["base_price_cents"], current["base_price_cents"])

      old_variants = Array(previous["variants"]).index_by { |variant| variant["external_id"].to_s }
      new_variants = Array(current["variants"]).index_by { |variant| variant["external_id"].to_s }
      new_variants.each do |external_id, variant|
        old = old_variants[external_id]
        next unless old
        events.concat(availability_events(old, variant, external_id))
        events << event!("PRICE_CHANGED", external_id, old["price_cents"], variant["price_cents"]) if changed_price?(old["price_cents"], variant["price_cents"])
        if old["visible_quantity"] != variant["visible_quantity"] && (!old["visible_quantity"].nil? || !variant["visible_quantity"].nil?)
          events << event!("VISIBLE_QUANTITY_CHANGED", external_id, old["visible_quantity"], variant["visible_quantity"])
        end
      end
      (old_variants.keys - new_variants.keys).each do |external_id|
        events << event!("REMOVED", external_id, old_variants[external_id], {})
      end
      evaluate_targets!(previous, current, events)
      events
    end

    def availability_events(previous, current, external_id)
      before = previous["availability"]
      after = current["availability"]
      return [] if before == after
      return [ event!("RESTOCKED", external_id, before, after) ] if before != "in_stock" && after == "in_stock"
      return [ event!("SOLD_OUT", external_id, before, after) ] if before == "in_stock" && after == "out_of_stock"
      []
    end

    def evaluate_targets!(previous, current, events)
      old_variants = Array(previous["variants"]).index_by { |variant| variant["external_id"].to_s }
      new_variants = Array(current["variants"]).index_by { |variant| variant["external_id"].to_s }
      @listing.subscriptions.where(active: true).where.not(target_price_cents: nil).find_each do |subscription|
        before = subscription.variant_external_id.blank? ? previous["base_price_cents"] : old_variants.dig(subscription.variant_external_id, "price_cents")
        after = subscription.variant_external_id.blank? ? current["base_price_cents"] : new_variants.dig(subscription.variant_external_id, "price_cents")
        next unless after
        if after > subscription.target_price_cents
          subscription.update!(target_armed: true) unless subscription.target_armed?
        elsif subscription.target_armed? && before && before > subscription.target_price_cents
          target_event = event!(
            "TARGET_REACHED", subscription.variant_external_id, before, after,
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
