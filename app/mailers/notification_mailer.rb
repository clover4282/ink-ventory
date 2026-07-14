class NotificationMailer < ApplicationMailer
  def verification(delivery)
    @delivery = delivery
    @address = delivery.user.notification_address
    mail(to: delivery.recipient, subject: "[Ink-ventory] 알림 이메일을 인증해 주세요")
  end

  def event_alert(delivery)
    @delivery = delivery
    @event = ChangeEvent.find(delivery.metadata.fetch("event_id"))
    @subscription = Subscription.find_by(id: delivery.metadata["subscription_id"])
    @address = delivery.user.notification_address
    mail(to: delivery.recipient, subject: "[Ink-ventory] #{event_label(@event.kind)} - #{@event.listing.title}")
  end

  def digest(delivery)
    @delivery = delivery
    @events = ChangeEvent.where(id: delivery.metadata.fetch("event_ids")).includes(:listing).order(:occurred_at)
    @address = delivery.user.notification_address
    mail(to: delivery.recipient, subject: "[Ink-ventory] #{delivery.metadata['date']} 관심 상품 변경 요약")
  end

  helper_method :event_label, :formatted_value

  private
    def event_label(kind)
      {
        "RESTOCKED" => "재입고", "SOLD_OUT" => "품절", "PRICE_CHANGED" => "가격 변경",
        "TARGET_REACHED" => "목표가 도달", "VISIBLE_QUANTITY_CHANGED" => "공개 수량 변경",
        "NEW_SEARCH_RESULT" => "새 검색 후보", "REMOVED" => "판매 종료"
      }.fetch(kind, kind)
    end

    def formatted_value(value)
      value.is_a?(Numeric) ? "#{ActiveSupport::NumberHelper.number_to_delimited(value)}원" : value.to_s
    end
end
