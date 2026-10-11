class ApplicationMailer < ActionMailer::Base
  # Owner-chosen Resend sender on the verified contact.mohamedhnoor.com domain (2026-10-11).
  default from: "FXTrack <info@contact.mohamedhnoor.com>"
  layout "mailer"
end
