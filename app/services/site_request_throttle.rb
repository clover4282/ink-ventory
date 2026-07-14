require "fileutils"

class SiteRequestThrottle
  def self.call(site)
    lock_dir = Rails.root.join("tmp/site-request-locks")
    FileUtils.mkdir_p(lock_dir)

    File.open(lock_dir.join("#{site.code}.lock"), File::RDWR | File::CREAT, 0o644) do |lock|
      lock.flock(File::LOCK_EX)
      site.reload
      return if !site.enabled? || site.backoff_until&.future?

      wait = site.min_delay_seconds.to_f - (Time.current - site.last_request_at) if site.last_request_at
      sleep(wait + rand(0.0..0.4)) if wait&.positive?
      response = yield
      site.update!(last_request_at: Time.current)
      response
    end
  end
end
