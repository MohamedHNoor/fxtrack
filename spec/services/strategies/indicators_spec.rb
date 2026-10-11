require "rails_helper"

RSpec.describe Strategies::Indicators do
  it "seeds the EMA with a simple average" do
    ema = described_class.ema([ 1, 2, 3, 4, 5 ].map { BigDecimal(_1) }, 3)
    expect(ema.map { _1.round(4) }).to eq([ BigDecimal("2"), BigDecimal("3"), BigDecimal("4") ])
  end

  it "computes Wilder's ATR from true ranges" do
    bars = [ bar(Time.utc(2026, 9, 1), "1.0", "1.0", wick: "0.1"), bar(Time.utc(2026, 9, 1, 1), "1.0", "1.0", wick: "0.1"),
             bar(Time.utc(2026, 9, 1, 2), "1.0", "1.0", wick: "0.2") ]
    # True ranges 0.2 and 0.4; ATR(1) = 0.4 after smoothing with period 1.
    expect(described_class.atr(bars, 1)).to eq(BigDecimal("0.4"))
    expect(described_class.atr(bars.first(1), 1)).to be_nil
  end

  it "confirms swings only with enough candles on both sides" do
    h1 = buy_setup[:h1]
    lows = described_class.swings(h1, 3, :low).map { |index| h1[index].low }
    expect(lows).to include(BigDecimal("1.1249"))
    expect(described_class.swings(h1.first(59), 3, :low)).to be_empty
  end

  it "recognises engulfing candles" do
    down, up = bar(Time.utc(2026, 9, 1), "1.1282", "1.1256"), bar(Time.utc(2026, 9, 1, 1), "1.1255", "1.1290")
    expect(described_class.bullish_engulfing?(down, up)).to be(true)
    expect(described_class.bearish_engulfing?(down, up)).to be(false)
  end
end
