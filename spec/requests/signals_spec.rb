require "rails_helper"

RSpec.describe "Signals and strategies" do
  let!(:owner) { User.create!(email_address: "owner@example.com", password: "correct horse battery") }
  let(:setup) { buy_setup }

  before { post login_path, params: { email_address: owner.email_address, password: "correct horse battery" } }

  def store(symbol, interval, bars)
    request = ProviderRequest.create!(symbol: symbol, interval: interval, endpoint: "time_series", requested_at: Time.current, status: "success")
    bars.each { |b| Candle.create!(provider_request: request, symbol: symbol, interval: interval, opened_at: b.opened_at, open: b.open, high: b.high, low: b.low, close: b.close) }
  end

  def generate_signal
    owner.create_trading_account!(starting_capital: 2000, started_at: 1.month.ago)
    store("EUR/USD", "1h", setup[:h1])
    store("EUR/USD", "4h", setup[:h4])
    store("NZD/USD", "1h", [ bar(setup[:h1].last.opened_at, "0.5995", "0.6000") ])
    now = setup[:h1].last.opened_at + 1.hour + 5.minutes
    Strategies::SignalEngine.new(clock: -> { now }).run
    now
  end

  it "shows an active signal with its plan, sizing and the latest WAIT reasons" do
    now = generate_signal
    travel_to(now) { get signals_path }
    expect(response.body).to include("Active trade ideas", "EUR/USD", "BUY", "1.12900", "1.12410", "lots")
    expect(response.body).to include("Latest analysis", "NZD/USD", "Not enough completed candles")

    signal = TradeSignal.sole
    travel_to(now) { get signal_path(signal) }
    expect(response.body).to include("Why this signal", "Pullback to support at 1.1249", "Position size working", "Active")
  end

  it "warns about correlated US dollar exposure" do
    now = generate_signal
    first = TradeSignal.sole
    second_run = StrategyRun.create!(strategy_version: first.strategy_version, symbol: "AUD/USD", candle_opened_at: first.source_opened_at,
      verdict: "buy", evaluated_at: now)
    TradeSignal.create!(first.attributes.except("id", "strategy_run_id", "symbol", "created_at", "updated_at").merge(strategy_run: second_run, symbol: "AUD/USD"))
    travel_to(now) { get signals_path }
    expect(response.body).to include("Correlated US dollar exposure", "buy EUR/USD and buy AUD/USD all sell US dollars")
  end

  it "versions edits, clones disabled copies and archives strategies" do
    get strategies_path
    strategy = owner.strategies.sole
    expect(response.body).to include("Trend Pullback Confirmation V1", "version 1 of 1")

    patch strategy_path(strategy), params: { config: StrategyVersion::DEFAULTS.merge("expiry_minutes" => "45") }
    expect(strategy.versions.pluck(:number)).to eq([ 1, 2 ])
    expect(strategy.current_version.setting("expiry_minutes")).to eq(45)
    expect(strategy.versions.first.setting("expiry_minutes")).to eq(30)

    patch strategy_path(strategy), params: { config: StrategyVersion::DEFAULTS.merge("ema_fast" => "60") }
    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("shorter than ema slow")

    post clone_strategy_path(strategy)
    copy = owner.strategies.find_by!(name: "Trend Pullback Confirmation V1 copy")
    expect(copy).to have_attributes(enabled: false)
    patch archive_strategy_path(strategy)
    expect(strategy.reload).to have_attributes(enabled: false, archived_at: be_present)
    patch toggle_strategy_path(strategy)
    expect(strategy.reload.enabled).to be(false)
  end

  it "does not expose another account's strategies" do
    get strategies_path
    expect { get edit_strategy_path(id: owner.strategies.maximum(:id) + 1) }.not_to raise_error
    expect(response).to have_http_status(:not_found)
  end
end
