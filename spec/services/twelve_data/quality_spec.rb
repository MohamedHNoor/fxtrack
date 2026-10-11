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

RSpec.describe TwelveData::Quality, "market closure" do
  def evaluate(now, interval, stamps)
    values = stamps.map { |stamp| { "datetime" => stamp.strftime("%Y-%m-%d %H:%M:%S"), "open" => "1.1", "high" => "1.3", "low" => "1.0", "close" => "1.2" } }
    payload = { "meta" => { "symbol" => "EUR/USD", "interval" => interval, "type" => "Physical Currency" }, "values" => values }
    described_class.new(clock: -> { now }, fingerprint_key: "a" * 32).evaluate(payload, symbol: "EUR/USD", interval: interval)
  end

  def hours(day, range) = range.map { |hour| Time.utc(2026, 10, day, hour) }

  it "reports a weekend-only window as closed without fingerprints" do
    result = evaluate(Time.utc(2026, 10, 11, 16, 30), "1h", hours(11, 8..15))
    expect(result).to include(status: "closed", closed_count: 0, closure_count: 8, fingerprints: {})
  end

  it "accepts data ending at the Friday close during the weekend" do
    result = evaluate(Time.utc(2026, 10, 10, 12), "1h", hours(9, 18..23))
    expect(result).to include(status: "closed", closed_count: 3, closure_count: 3, gap_count: 0, latest_closed_at: Time.utc(2026, 10, 9, 21))
  end

  it "flags a missing final Friday candle as stale" do
    result = evaluate(Time.utc(2026, 10, 10, 12), "1h", hours(9, [ 18, 19, 21, 22 ]))
    expect(result[:status]).to eq("stale")
  end

  it "does not count the weekend as a gap after the reopen" do
    stamps = hours(9, [ 12, 16, 20 ]) + [ Time.utc(2026, 10, 12, 0) ]
    expect(evaluate(Time.utc(2026, 10, 12, 5), "4h", stamps)).to include(status: "valid", gap_count: 0, closed_count: 4)
  end
end

RSpec.describe TwelveData::Quality, "invalid candles" do
  let(:now) { Time.utc(2026, 10, 12, 12) }
  let(:bar) { { "datetime" => "2026-10-12 08:00:00", "open" => "1.1", "high" => "1.3", "low" => "1.0", "close" => "1.2" } }

  def evaluate(bars)
    payload = { "meta" => { "symbol" => "EUR/USD", "interval" => "1h", "type" => "Physical Currency" }, "values" => bars }
    described_class.new(clock: -> { now }, fingerprint_key: "a" * 32).evaluate(payload, symbol: "EUR/USD", interval: "1h")
  end

  it "drops and counts an inconsistent candle, leaving its slot as a gap" do
    bars = [ bar, bar.merge("datetime" => "2026-10-12 09:00:00", "high" => "1.15"), bar.merge("datetime" => "2026-10-12 10:00:00") ]
    result = evaluate(bars)
    expect(result).to include(status: "gaps", invalid_count: 1, closed_count: 2, gap_count: 1)
    expect(result[:fingerprints].keys).to eq([ Time.utc(2026, 10, 12, 8), Time.utc(2026, 10, 12, 10) ])
  end

  it "rejects a window where every candle is invalid" do
    expect(evaluate([ bar.merge("low" => "2") ])).to include(status: "invalid", invalid_count: 1)
  end
end
