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

RSpec.describe TwelveData::Collection, "market closure" do
  let(:probe) { instance_double(TwelveData::Probe) }

  def called_at(now)
    called = []
    allow(probe).to receive(:run) { |**args| called << args; "success" }
    described_class.new(probe: probe, clock: -> { now }).run
    called
  end

  def collected(requested_at, latest_closed_at)
    request = ProviderRequest.create!(symbol: "EUR/USD", interval: "1h", endpoint: "time_series", requested_at: requested_at, status: "success")
    request.create_data_quality_metric!(status: "closed", evaluated_at: requested_at, latest_closed_at: latest_closed_at,
      closed_count: 0, closure_count: 8, incomplete_count: 0, duplicate_count: 0, gap_count: 0)
  end

  it "waits over the weekend until the first trading candle after the reopen closes" do
    collected(Time.utc(2026, 10, 9, 21, 2), Time.utc(2026, 10, 9, 21))
    expect(called_at(Time.utc(2026, 10, 11, 22))).not_to include(symbol: "EUR/USD", interval: "1h")
    expect(called_at(Time.utc(2026, 10, 11, 22, 1))).to include(symbol: "EUR/USD", interval: "1h")
  end

  it "schedules a weekend-only result from the next expected trading close" do
    collected(Time.utc(2026, 10, 11, 16, 30), nil)
    expect(called_at(Time.utc(2026, 10, 11, 21, 30))).not_to include(symbol: "EUR/USD", interval: "1h")
    expect(called_at(Time.utc(2026, 10, 11, 22, 1))).to include(symbol: "EUR/USD", interval: "1h")
  end
end

RSpec.describe TwelveData::Collection, "history isolation" do
  it "ignores history measurements when choosing due collection requests" do
    now = Time.utc(2026, 10, 12, 12, 1)
    request = ProviderRequest.create!(symbol: "EUR/USD", interval: "1h", endpoint: "time_series", requested_at: now - 120, status: "success")
    request.create_data_quality_metric!(status: "valid", evaluated_at: now - 120, latest_closed_at: now - 61,
      closed_count: 1, incomplete_count: 0, duplicate_count: 0, gap_count: 0)
    ProviderRequest.create!(symbol: "EUR/USD", interval: "1h", endpoint: "time_series_history", requested_at: now - 30, status: "invalid_data")
    probe = instance_double(TwelveData::Probe)
    called = []
    allow(probe).to receive(:run) { |**args| called << args; "success" }
    described_class.new(probe: probe, clock: -> { now }).run
    expect(called).not_to include(symbol: "EUR/USD", interval: "1h")
  end
end

RSpec.describe TwelveData::Collection, "stale and gapped results" do
  let(:probe) { instance_double(TwelveData::Probe) }
  let(:requested_at) { Time.utc(2026, 10, 12, 11, 1, 30) }

  def called_at(now)
    called = []
    allow(probe).to receive(:run) { |**args| called << args; "success" }
    described_class.new(probe: probe, clock: -> { now }).run
    called
  end

  def rejected(status, latest_closed_at)
    request = ProviderRequest.create!(symbol: "EUR/USD", interval: "1h", endpoint: "time_series", requested_at: requested_at,
      status: "invalid_data", error_code: "invalid_response")
    request.create_data_quality_metric!(status: status, evaluated_at: requested_at, latest_closed_at: latest_closed_at,
      closed_count: 8, incomplete_count: 0, duplicate_count: 0, gap_count: status == "gaps" ? 1 : 0)
  end

  it "waits for the next expected close after a gapped result" do
    rejected("gaps", Time.utc(2026, 10, 12, 11))
    expect(called_at(Time.utc(2026, 10, 12, 11, 30))).not_to include(symbol: "EUR/USD", interval: "1h")
    expect(called_at(Time.utc(2026, 10, 12, 12, 1))).to include(symbol: "EUR/USD", interval: "1h")
  end

  it "waits for the next expected close after a stale result" do
    rejected("stale", Time.utc(2026, 10, 12, 9))
    expect(called_at(Time.utc(2026, 10, 12, 11, 30))).not_to include(symbol: "EUR/USD", interval: "1h")
    expect(called_at(Time.utc(2026, 10, 12, 12, 1))).to include(symbol: "EUR/USD", interval: "1h")
  end

  it "still retries other invalid data after a minute" do
    rejected("invalid", nil)
    expect(called_at(requested_at + 61)).to include(symbol: "EUR/USD", interval: "1h")
  end
end
