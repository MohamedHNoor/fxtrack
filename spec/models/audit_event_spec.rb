require "rails_helper"

RSpec.describe AuditEvent do
  let(:owner) { User.create!(email_address: "owner@example.com", password: "correct horse battery") }
  let(:account) { owner.create_trading_account!(starting_capital: 2000, started_at: Time.utc(2026, 9, 1)) }
  let(:trade) do
    JournalTrade.new(trading_account: account).record!(
      { symbol: "EUR/USD", direction: "buy", status: "skipped", skipped_at: Time.utc(2026, 10, 12, 3) }, actor: owner
    )
  end

  def build_event(**attrs)
    AuditEvent.new({ user: owner, auditable: trade, action: "created",
                     changes_made: { "status" => [ nil, "skipped" ] } }.merge(attrs))
  end

  it "accepts the three valid actions (corrected requires a reason)" do
    expect(build_event(action: "created")).to be_valid
    expect(build_event(action: "updated")).to be_valid
    expect(build_event(action: "corrected", reason: "Typo in exit")).to be_valid
  end

  it "rejects an unknown action" do
    expect(build_event(action: "deleted")).not_to be_valid
  end

  it "requires a reason for corrected events" do
    expect(build_event(action: "corrected")).not_to be_valid
    expect(build_event(action: "corrected", reason: "")).not_to be_valid
    expect(build_event(action: "corrected", reason: "Typo in exit")).to be_valid
  end

  it "enforces the reason length limit" do
    expect(build_event(reason: "x" * 501)).not_to be_valid
    expect(build_event(reason: "x" * 500)).to be_valid
  end

  it "is readonly once persisted" do
    event = trade.audit_events.first
    expect { event.update!(reason: "x") }.to raise_error(ActiveRecord::ReadOnlyRecord)
  end

  it "cannot be destroyed" do
    event = trade.audit_events.first
    expect { event.destroy! }.to raise_error(ActiveRecord::ReadOnlyRecord)
  end
end
