class ApplicationMailer < ActionMailer::Base
  # Production delivery waits for an email provider decision (see docs/authentication.md).
  default from: "FXTrack <no-reply@example.com>"
  layout "mailer"
end
