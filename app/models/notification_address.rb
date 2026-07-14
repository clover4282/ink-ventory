class NotificationAddress < ApplicationRecord
  belongs_to :user

  before_validation :ensure_tokens

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :verification_token, :unsubscribe_token, presence: true, uniqueness: true

  def verify!
    update!(verified_at: Time.current, notifications_enabled: true, verification_token: SecureRandom.urlsafe_base64(32))
  end

  def reset_verification!
    self.verified_at = nil
    self.notifications_enabled = true
    self.verification_token = SecureRandom.urlsafe_base64(32)
  end

  private
    def ensure_tokens
      self.verification_token ||= SecureRandom.urlsafe_base64(32)
      self.unsubscribe_token ||= SecureRandom.urlsafe_base64(32)
    end
end
