require "rails_helper"

RSpec.describe Strategies::SignalEngine do
  let(:user) { User.create!(email_address: "owner@example.com", password: "correct horse battery") }
  let(:request) { ProviderRequest.create!(symbol: "EUR/USD", interval: "1h", endpoint: "time_series", requested_at: Time.current, status: "success") }
  let(:setup) { buy_setup }
  let(:now) { setup[:h1].last.opened_at + 1.hour + 5.minutes }

  before do
    user.create_trading_account!(starting_capital: 2000, started_at: 1.month.ago)
    store("EUR/USD", "1h", setup[:h1])
    store("EUR/USD", "4h", setup[:h4])
    store("NZD/USD", "1h", [ bar(setup[:h1].last.opened_at, "0.5995", "0.6000") ])
  end

  def store(symbol, interval, bars)
    bars.each do |b|
      Candle.create!(provider_request: request, symbol: symbol, interval: interval, opened_at: b.opened_at, open: b.open, high: b.high, low: b.low, close: b.close)
    end
  end

  def engine(at = now) = described_class.new(clock: -> { at })

  it "creates the default strategy, records the run and a sized active signal" do
    expect(engine.run).to eq(runs: 2, signals: 1)
    signal = TradeSignal.sole
    expect(signal).to have_attributes(symbol: "EUR/USD", direction: "buy", status: "active", entry: BigDecimal("1.129"))
    expect(signal.lots).to be_positive
    expect(signal.risk_at_size).to be <= signal.planned_risk
    expect(signal.expires_at).to eq(setup[:h1].last.opened_at + 1.hour + 30.minutes)
    expect(signal.evidence["sizing_steps"]).to include(a_string_including("1.5 pips of spread"))
    expect(StrategyRun.find_by(symbol: "NZD/USD").verdict).to eq("wait")
  end

  it "never duplicates a run or signal for the same candle" do
    engine.run
    expect(engine.run).to eq(runs: 0, signals: 0)
    expect(TradeSignal.count).to eq(1)
  end

  it "ignores stale data instead of creating retroactive signals" do
    expect(engine(now + 3.hours).run).to eq(runs: 0, signals: 0)
  end

  it "expires signals and invalidates them when a newer candle trades through the stop" do
    engine.run
    engine(now + 30.minutes).run
    expect(TradeSignal.sole.status).to eq("expired")

    TradeSignal.sole.update!(status: "active", expires_at: now + 2.hours)
    store("EUR/USD", "1h", [ bar(setup[:h1].last.opened_at + 1.hour, "1.1290", "1.1238") ])
    engine(now + 1.hour).run
    expect(TradeSignal.sole).to have_attributes(status: "invalidated", status_reason: "Stop level traded before entry")
  end

  it "skips disabled strategies and pairs" do
    Strategy.ensure_default_for(user)
    CurrencyPair.find_by!(symbol: "EUR/USD").update!(enabled: false)
    engine.run
    expect(StrategyRun.where(symbol: "EUR/USD")).to be_empty
    user.strategies.update_all(enabled: false)
    CurrencyPair.update_all(enabled: true)
    expect(engine.run).to eq(runs: 0, signals: 0)
  end
end
