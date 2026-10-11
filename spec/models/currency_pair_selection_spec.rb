require "rails_helper"

RSpec.describe CurrencyPairSelection do
  include ActiveJob::TestHelper

  let(:user) { User.create!(email_address: "owner@example.com", password: "correct horse battery") }

  def active_signal(symbol)
    Strategy.ensure_default_for(user)
    version = user.strategies.sole.current_version
    run = StrategyRun.create!(strategy_version: version, symbol: symbol, candle_opened_at: 1.hour.ago, verdict: "buy", evaluated_at: Time.current)
    TradeSignal.create!(strategy_version: version, strategy_run: run, symbol: symbol, direction: "buy", source_opened_at: 1.hour.ago,
      entry: 1.1, stop: 1.09, target: 1.12, entry_tolerance: 0.001, reward_ratio: 2, stop_pips: 100, generated_at: Time.current, expires_at: 30.minutes.from_now)
  end

  before { ActiveJob::Base.queue_adapter = :test }

  it "disables pairs, keeping history but invalidating their live signals" do
    signal = active_signal("NZD/USD")
    changes = described_class.new(ProviderRequest::SYMBOLS - [ "NZD/USD" ]).save
    expect(changes).to eq(enabled: [], disabled: [ "NZD/USD" ])
    expect(CurrencyPair.find_by!(symbol: "NZD/USD")).not_to be_enabled
    expect(signal.reload).to have_attributes(status: "invalidated", status_reason: "Pair disabled")
  end

  it "warms indicator history when a pair is enabled again" do
    CurrencyPair.find_by!(symbol: "USD/JPY").update!(enabled: false)
    expect { described_class.new(ProviderRequest::SYMBOLS).save }.to have_enqueued_job(PairWarmupJob).with("USD/JPY")
  end

  it "accepts an empty selection and ignores unknown symbols" do
    described_class.new([ "", "XAU/USD" ]).save
    expect(CurrencyPair.enabled).to be_empty
  end
end
