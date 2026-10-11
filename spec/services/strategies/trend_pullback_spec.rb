require "rails_helper"

RSpec.describe Strategies::TrendPullback do
  def evaluate(series, reward: 2)
    described_class.new(config: StrategyVersion::DEFAULTS, reward_ratio: reward, pip_size: BigDecimal("0.0001")).evaluate(**series)
  end

  it "proposes a buy with a buffered stop and reward-based target" do
    verdict = evaluate(buy_setup)
    expect(verdict.direction).to eq("buy")
    expect(verdict.entry).to eq(BigDecimal("1.1290"))
    # Stop = swing low 1.1249 - 0.5 x ATR; target = entry + 2 x risk.
    expect(verdict.stop).to be_within(BigDecimal("0.00001")).of(BigDecimal("1.12410"))
    expect(verdict.target).to eq(verdict.entry + (verdict.entry - verdict.stop) * 2)
    expect(verdict.reasons).to eq([ "H4 and H1 trends are bullish", "Pullback to support at 1.1249", "Bullish engulfing on the latest H1 candle" ])
    expect(verdict.evidence).to include("swing_level" => BigDecimal("1.1249"), "h4_trend" => "bullish")
  end

  it "proposes the mirrored sell" do
    verdict = evaluate(mirror(buy_setup))
    expect(verdict.direction).to eq("sell")
    expect(verdict.stop).to be > verdict.entry
    expect(verdict.target).to be < verdict.entry
  end

  it "waits when the next resistance leaves too little room" do
    expect(evaluate(buy_setup(resistance: true)).reasons.first).to match(/Next resistance at 1.1309 leaves less than 2.0R of room/)
    expect(evaluate(buy_setup(resistance: true), reward: "0.3").direction).to eq("buy")
  end

  it "waits without confirmation, on conflicting trends and on short history" do
    setup = buy_setup
    no_confirmation = setup.merge(h1: setup[:h1][0..-2] + [ bar(setup[:h1].last.opened_at, "1.1253", "1.1262") ])
    expect(evaluate(no_confirmation).reasons.first).to eq("No bullish engulfing confirmation on the latest H1 candle")
    expect(evaluate(setup.merge(h4: mirror(setup)[:h4])).reasons.first).to eq("H4 trend is bearish but H1 trend is bullish")
    expect(evaluate(setup.merge(h4: setup[:h4].first(10))).reasons.first).to start_with("Not enough completed candles")
  end
end
