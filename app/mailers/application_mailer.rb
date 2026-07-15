class ApplicationMailer < ActionMailer::Base
  self.deliver_later_queue_name = :mailers

  default from: ENV.fetch("MAIL_FROM", "Ink-ventory <alerts@example.com>")
  layout "mailer"
end
