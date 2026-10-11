require "rails_helper"

RSpec.describe "Alerts" do
  let!(:owner) { User.create!(email_address: "owner@example.com", password: "correct horse battery") }

  before do
    ActionMailer::Base.deliveries.clear
    post login_path, params: { email_address: owner.email_address, password: "correct horse battery" }
  end

  it "shows preferences without saving them, then saves on submit" do
    expect { get alerts_path }.not_to change(NotificationPreference, :count)
    expect(response.body).to include("Notification preferences", "New qualifying signal", "Telegram notifications", "Not available yet")
    patch alerts_path, params: { notification_preference: { email_enabled: "1", notify_new_signal: "1", notify_expired: "0", notify_invalidated: "1" } }
    expect(response).to redirect_to(alerts_path)
    expect(owner.notification_preference).to have_attributes(email_enabled: true, notify_invalidated: true, notify_expired: false)
  end

  it "sends a test email and reports failures" do
    post test_alerts_path
    expect(ActionMailer::Base.deliveries.sole.subject).to eq("FXTrack test alert")
    follow_redirect!
    expect(response.body).to include("Test email sent to owner@example.com")

    allow(SignalMailer).to receive(:with).and_raise(Net::SMTPAuthenticationError.new("535"))
    post test_alerts_path
    follow_redirect!
    expect(response.body).to include("Test email failed: Net::SMTPAuthenticationError")
  end
end
