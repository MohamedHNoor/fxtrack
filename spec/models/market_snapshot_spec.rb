require "rails_helper"

RSpec.describe MarketSnapshot do
  let(:request) { ProviderRequest.create!(symbol: "EUR/USD", interval: "1h", endpoint: "time_series", requested_at: Time.utc(2026, 10, 13, 10, 1), status: "success") }

  def candle(hour, close)
    Candle.create!(provider_request: request, symbol: "EUR/USD", interval: "1h", opened_at: Time.utc(2026, 10, 13, hour),
      open: 1.1, high: 1.3, low: 1.0, close: close)
  end

  def snapshot(now)
    described_class.for("EUR/USD", "1h", now: now)
  end

  it "reports no data before any candle is stored" do
    expect(snapshot(Time.utc(2026, 10, 13, 12)).state).to eq(:no_data)
  end

  it "is fresh when the last expected trading candle is stored and stale otherwise" do
    candle(8, 1.2)
    candle(9, 1.25)
    expect(snapshot(Time.utc(2026, 10, 13, 10, 30)).state).to eq(:fresh)
    expect(snapshot(Time.utc(2026, 10, 13, 12, 30)).state).to eq(:stale)
  end

  it "reports the weekend closure instead of staleness" do
    candle(9, 1.2)
    expect(snapshot(Time.utc(2026, 10, 17, 12)).state).to eq(:market_closed)
  end

  it "flags a failing provider" do
    candle(9, 1.2)
    request.update!(status: "provider_failure", error_code: "timeout")
    expect(snapshot(Time.utc(2026, 10, 13, 10, 30)).state).to eq(:provider_failure)
  end

  it "computes the change from the previous close" do
    candle(8, 1.2)
    candle(9, 1.26)
    result = snapshot(Time.utc(2026, 10, 13, 10, 30))
    expect(result.change).to eq(BigDecimal("0.06"))
    expect(result.change_percent).to eq(5.0)
  end
end
