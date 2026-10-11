require "rails_helper"

RSpec.describe TwelveData::Quality do
  let(:now) { Time.utc(2026, 10, 12, 12) }
  let(:evaluator) { described_class.new(clock: -> { now }) }
  let(:bar) { { "datetime" => "2026-10-12 08:00:00", "open" => "1.1", "high" => "1.3", "low" => "1.0", "close" => "1.2" } }

  def payload(symbol, interval, bars)
    { "meta" => { "symbol" => symbol, "interval" => interval, "type" => "Physical Currency" }, "values" => bars }
  end

  ProviderRequest::SYMBOLS.product(ProviderRequest::INTERVALS).each do |symbol, interval|
    it "validates #{symbol} #{interval} with completed UTC candles" do
      result = evaluator.evaluate(payload(symbol, interval, [ bar ]), symbol: symbol, interval: interval)
      expect(result[:closed_count]).to eq(1)
      expect(result[:latest_closed_at]).to eq(Time.utc(2026, 10, 12, 8) + described_class::DURATIONS[interval])
      expect(result).not_to have_key(:prices)
    end
  end

  it "counts duplicate candles once" do
    result = evaluator.evaluate(payload("EUR/USD", "4h", [ bar, bar ]), symbol: "EUR/USD", interval: "4h")
    expect(result).to include(closed_count: 1, duplicate_count: 1, status: "valid")
  end

  it "rejects contradictory duplicates" do
    result = evaluator.evaluate(payload("EUR/USD", "4h", [ bar, bar.merge("close" => "1.25") ]), symbol: "EUR/USD", interval: "4h")
    expect(result[:status]).to eq("invalid")
  end

  it "excludes incomplete candles" do
    result = evaluator.evaluate(payload("EUR/USD", "4h", [ bar.merge("datetime" => "2026-10-12 11:00:00") ]), symbol: "EUR/USD", interval: "4h")
    expect(result).to include(closed_count: 0, incomplete_count: 1, status: "empty")
  end

  it "rejects invalid OHLC and timestamps" do
    [ bar.merge("low" => "2"), bar.merge("high" => "NaN"), bar.merge("datetime" => "2026-02-30 08:00:00") ].each do |invalid|
      expect(evaluator.evaluate(payload("EUR/USD", "4h", [ invalid ]), symbol: "EUR/USD", interval: "4h")[:status]).to eq("invalid")
    end
  end

  it "reports missing intervals without assuming a closure" do
    result = evaluator.evaluate(payload("EUR/USD", "1h", [ bar, bar.merge("datetime" => "2026-10-12 11:00:00") ]), symbol: "EUR/USD", interval: "1h")
    expect(result).to include(status: "gaps", gap_count: 2)
  end
end

RSpec.describe TwelveData::Quality, "fingerprints" do
  let(:now) { Time.utc(2026, 10, 12, 12) }
  let(:bar) { { "datetime" => "2026-10-12 08:00:00", "open" => "1.1", "high" => "1.3", "low" => "1.0", "close" => "1.2" } }

  def fingerprints(bars, key: "a" * 32)
    payload = { "meta" => { "symbol" => "EUR/USD", "interval" => "1h", "type" => "Physical Currency" }, "values" => bars }
    described_class.new(clock: -> { now }, fingerprint_key: key).evaluate(payload, symbol: "EUR/USD", interval: "1h")[:fingerprints]
  end

  it "keys closed candles by open time with a keyed digest and no prices" do
    result = fingerprints([ bar, bar.merge("datetime" => "2026-10-12 11:30:00") ])
    expect(result.keys).to eq([ Time.utc(2026, 10, 12, 8) ])
    expect(result.values.first).to match(/\A[0-9a-f]{64}\z/)
    expect(fingerprints([ bar ], key: "b" * 32)).not_to eq(result)
  end

  it "treats equal decimal prices as the same candle and changed prices as different" do
    expect(fingerprints([ bar.merge("close" => "1.20") ])).to eq(fingerprints([ bar ]))
    expect(fingerprints([ bar.merge("close" => "1.21") ])).not_to eq(fingerprints([ bar ]))
  end
end
