require "rails_helper"

RSpec.describe TwelveData::Collection do
  let(:now) { Time.utc(2026, 10, 12, 12, 1) }
  let(:probe) { instance_double(TwelveData::Probe) }

  it "stops a cycle immediately when quota is unavailable" do
    expect(probe).to receive(:run).once.and_return("quota_paused")
    result = described_class.new(probe: probe, clock: -> { now }).run
    expect(result[:results].size).to eq(1)
    expect(result[:results].first[:status]).to eq("quota_paused")
  end

  it "waits for the next observed H4 close while H1 is due" do
    request = ProviderRequest.create!(symbol: "EUR/USD", interval: "4h", endpoint: "time_series", requested_at: now - 120, status: "success")
    request.create_data_quality_metric!(status: "valid", evaluated_at: now - 120, latest_closed_at: now - 3600,
      closed_count: 1, incomplete_count: 0, duplicate_count: 0, gap_count: 0)
    called = []
    allow(probe).to receive(:run) { |**args| called << args; "success" }
    described_class.new(probe: probe, clock: -> { now }).run
    expect(called).not_to include(symbol: "EUR/USD", interval: "4h")
    expect(called).to include(symbol: "EUR/USD", interval: "1h")
    expect(called.size).to eq(13)
  end

  it "reports partial failure without discarding other pair outcomes" do
    allow(probe).to receive(:run).and_return("provider_failure", "quota_paused")
    result = described_class.new(probe: probe, clock: -> { now }).run
    expect(result[:status]).to eq("partial_failure")
    expect(result[:results].size).to eq(2)
  end
end
