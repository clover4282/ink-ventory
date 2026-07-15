require "openssl"

class LoginChallenge < ApplicationRecord
  CODE_TTL = 10.minutes
  RESEND_DELAY = 60.seconds
  MAX_ATTEMPTS = 5
  LOCKOUT_DURATION = 1.hour

  class RecentlySent < StandardError; end
  class Locked < StandardError; end

  normalizes :email, with: ->(email) { email.to_s.strip.downcase }

  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :code_digest, :expires_at, :sent_at, presence: true

  def self.issue!(email, now: Time.current)
    email = normalize_email(email)
    challenge = find_or_initialize_by(email: email)
    raise Locked if challenge.locked_until && challenge.locked_until > now
    raise RecentlySent if challenge.sent_at && challenge.sent_at > now - RESEND_DELAY

    code = SecureRandom.random_number(1_000_000).to_s.rjust(6, "0")
    reset_attempts = challenge.new_record? || challenge.locked_until.present? || challenge.expires_at <= now
    challenge.update!(code_digest: digest(email, code), expires_at: now + CODE_TTL, sent_at: now, attempts: reset_attempts ? 0 : challenge.attempts, locked_until: nil)
    code
  rescue ActiveRecord::RecordNotUnique
    raise RecentlySent
  end

  def verify(code, now: Time.current)
    result = :invalid
    with_lock do
      if locked_until && locked_until > now
        result = :locked
      elsif expires_at <= now
        destroy!
        result = :expired
      elsif ActiveSupport::SecurityUtils.secure_compare(code_digest, self.class.digest(email, code.to_s))
        destroy!
        result = :verified
      elsif attempts + 1 >= MAX_ATTEMPTS
        update!(attempts: attempts + 1, locked_until: now + LOCKOUT_DURATION)
        result = :locked
      else
        update!(attempts: attempts + 1)
      end
    end
    result
  end

  def self.normalize_email(email)
    email.to_s.strip.downcase
  end

  def self.digest(email, code)
    OpenSSL::HMAC.hexdigest("SHA256", Rails.application.secret_key_base, "#{email}\0#{code}")
  end
end
