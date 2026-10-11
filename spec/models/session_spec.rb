require "rails_helper"

RSpec.describe Session do
  let(:user) { User.create!(email_address: "owner@example.com", password: "correct horse battery") }
  let(:now) { Time.utc(2026, 10, 12, 12) }

  def session_at(created_at, last_active_at = created_at)
    user.sessions.create!(created_at: created_at, last_active_at: last_active_at)
  end

  it "expires after seven idle days" do
    expect(session_at(now - 6.days).expired?(now)).to be(false)
    expect(session_at(now - 8.days).expired?(now)).to be(true)
  end

  it "expires after thirty days even with recent activity" do
    expect(session_at(now - 29.days, now - 1.hour).expired?(now)).to be(false)
    expect(session_at(now - 31.days, now - 1.hour).expired?(now)).to be(true)
  end

  it "selects only unexpired sessions as active" do
    current = session_at(now - 1.day)
    session_at(now - 8.days)
    session_at(now - 31.days, now - 1.hour)
    expect(described_class.active(now)).to contain_exactly(current)
  end

  it "records activity at most hourly" do
    record = session_at(now - 2.days, now - 30.minutes)
    expect { record.record_activity(now) }.not_to change { record.reload.last_active_at }
    record.update_column(:last_active_at, now - 2.hours)
    expect { record.record_activity(now) }.to change { record.reload.last_active_at }.to(now)
  end

  it "reports the earlier of the idle and absolute expiry" do
    expect(session_at(now - 28.days, now).expires_at).to eq(now - 28.days + 30.days)
    expect(session_at(now - 1.day, now - 1.day).expires_at).to eq(now - 1.day + 7.days)
  end
end
