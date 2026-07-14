class ImmediateNotificationBuilder
  def self.call(event)
    new(event).call
  end

  def initialize(event)
    @event = event
  end

  def call
    case @event.kind
    when "RESTOCKED"
      matching_subscriptions.where(notify_restock: true).find_each { |subscription| enqueue(subscription) }
    when "TARGET_REACHED"
      subscription = Subscription.find_by(id: @event.current_value["subscription_id"])
      enqueue(subscription) if subscription&.active?
    end
  end

  private
    def matching_subscriptions
      @event.listing.subscriptions.joins(:watch_group).where(active: true, watch_groups: { active: true }).where(
        variant_external_id: [ "", @event.variant_external_id ]
      )
    end

    def enqueue(subscription)
      delivery = NotificationOutbox.enqueue(
        user: subscription.user, kind: "event", dedupe_key: "event:#{@event.id}:user:#{subscription.user.id}",
        metadata: { "event_id" => @event.id, "subscription_id" => subscription.id }
      )
      EventReceipt.find_or_create_by!(user: subscription.user, change_event: @event, channel: "immediate") do |receipt|
        receipt.mail_delivery = delivery
      end if delivery
    end
end
