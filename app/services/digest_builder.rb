class DigestBuilder
  KINDS = %w[SOLD_OUT VISIBLE_QUANTITY_CHANGED NEW_SEARCH_RESULT REMOVED].freeze

  def self.call(user, date: Time.zone.today)
    new(user, date: date).call
  end

  def initialize(user, date:)
    @user = user
    @date = date
  end

  def call
    return unless @user.verified_for_notifications?
    subscriptions = @user.subscriptions.joins(:watch_group).where(active: true, watch_groups: { active: true }).to_a
    subscription_listing_ids = subscriptions.map(&:listing_id)
    watched_query_ids = @user.search_watches.where(active: true).pluck(:search_query_id)
    events = ChangeEvent.where(kind: KINDS).where(created_at: @date.all_day)
      .where("listing_id IN (?) OR search_query_id IN (?)", subscription_listing_ids, watched_query_ids)
      .where.not(id: @user.event_receipts.select(:change_event_id)).order(:occurred_at).to_a.select do |event|
        if event.kind == "NEW_SEARCH_RESULT"
          watched_query_ids.include?(event.search_query_id)
        else
          subscriptions.any? do |subscription|
            subscription.listing_id == event.listing_id &&
              (event.variant_external_id.blank? || subscription.variant_external_id.blank? || subscription.variant_external_id == event.variant_external_id)
          end
        end
      end
    return if events.empty?

    delivery = NotificationOutbox.enqueue(
      user: @user, kind: "digest", dedupe_key: "digest:#{@user.id}:#{@date}",
      metadata: { "event_ids" => events.map(&:id), "date" => @date.to_s }
    )
    events.each do |event|
      EventReceipt.find_or_create_by!(user: @user, change_event: event, channel: "digest") { |receipt| receipt.mail_delivery = delivery }
    end
    delivery
  end
end
