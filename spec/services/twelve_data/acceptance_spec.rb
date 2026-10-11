require "rails_helper"

RSpec.describe TwelveData::Acceptance do
  let(:now) { Time.utc(2026, 10, 14, 12) }
  let(:result) { described_class.new(clock: -> { now }).call }

  def request(endpoint, at, symbol: "EUR/USD", interval: "1h", status: "success")
    ProviderRequest.create!(symbol: symbol, interval: interval, endpoint: endpoint, requested_at: at, status: status)
  end

  def metric(provider_request, **counts)
    provider_request.create_data_quality_metric!(status: "valid", evaluated_at: provider_request.requested_at, closed_count: 1,
      incomplete_count: 0, duplicate_count: 0, gap_count: 0, **counts)
  end

  it "is pending with no evidence and reports the recorded retention decision" do
    expect(result[:gate]).to eq("pending")
    expect(result[:checks][:retention][:pass]).to be(true)
    expect(result[:checks][:live_hours][:detail]).to start_with("0 of 48")
    expect(result[:combos].size).to eq(14)
  end

  it "counts distinct trading hours but not weekend hours" do
    request("time_series", Time.utc(2026, 10, 12, 1, 5))
    request("time_series", Time.utc(2026, 10, 12, 1, 40))
    request("time_series", Time.utc(2026, 10, 12, 2, 5))
    request("time_series", Time.utc(2026, 10, 11, 18, 5)) # Sunday closure, before the live start
    expect(result[:live_hours]).to eq(2)
  end

  it "fails live reproducibility when any mismatch is recorded" do
    metric(request("time_series", Time.utc(2026, 10, 12, 3)), reproduced_count: 7, mismatch_count: 1)
    row = result[:combos].find { |item| item[:symbol] == "EUR/USD" && item[:interval] == "1h" }
    expect(row).to include(reproduced: 7, mismatches: 1)
    expect(result[:checks][:live_reproducibility][:pass]).to be(false)
  end

  it "requires two clean history windows per combination for the revision check" do
    metric(request("time_series_history", Time.utc(2026, 10, 11, 16)))
    metric(request("time_series_history", Time.utc(2026, 10, 11, 23)), reproduced_count: 3565)
    row = result[:combos].find { |item| item[:symbol] == "EUR/USD" && item[:interval] == "1h" }
    expect(row).to include(history_measured: true, history_repeated: true, history_mismatches: 0)
    expect(result[:checks][:revision_check][:pass]).to be(false)
  end

  it "reports peak quota usage" do
    3.times { |i| request("time_series", Time.utc(2026, 10, 12, 4, 0, i), symbol: ProviderRequest::SYMBOLS[i]) }
    expect(result[:quota]).to include(max_per_minute: 3, max_per_day: 3, total: 3)
    expect(result[:checks][:quota][:pass]).to be(true)
  end
end
