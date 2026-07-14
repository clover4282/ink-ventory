class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAIL_FROM", "Ink-ventory <alerts@example.com>")
  layout "mailer"
end
