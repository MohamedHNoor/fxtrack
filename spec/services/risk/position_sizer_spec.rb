require "rails_helper"

RSpec.describe Risk::PositionSizer do
  let(:user) { User.create!(email_address: "owner@example.com", password: "correct horse battery") }
  let(:profile) { RiskProfile.for(user) }
  let(:candle) { Data.define(:close) }
  let(:rates) do
    { "NZD/USD" => candle.new(BigDecimal("0.60")), "EUR/USD" => candle.new(BigDecimal("1.12")),
      "USD/JPY" => candle.new(BigDecimal("150")) }
  end

  def size(balance: BigDecimal("2000"), rates: self.rates, **trade)
    described_class.new(profile: profile, balance: balance, conversion: Risk::Conversion.new(rates: rates)).call(**trade)
  end

  it "matches the worked example: NZ$2,000 at 1% with a 40-pip EUR/USD stop is 0.03 lots" do
    result = size(symbol: "EUR/USD")
    expect(result).to be_ok
    expect(result.planned_risk).to eq(20)
    expect(result.lots).to eq(BigDecimal("0.03"))
    expect(result.units).to eq(3000)
    expect(result.risk_at_size).to eq(BigDecimal("20"))
    expect(result.reward_at_size).to eq(BigDecimal("40"))
    expect(result.steps).to eq([
      "Risking 1% of NZ$2,000.00: 2000 x 0.01 = NZ$20.00",
      "NZ$1 = US$0.6, so the US-dollar risk budget is 20 x 0.6 = US$12.00",
      "With a 40-pip stop and a EUR/USD standard-lot pip value of US$10.00:",
      "Lots = 12 / (40 x 10) = 0.03",
      "At 0.03 lots, a 40-pip adverse move costs approximately NZ$20.00, excluding trading costs, slippage and currency conversion fees."
    ])
  end

  it "builds buy and sell plans from the latest price, stop distance and reward multiple" do
    plans = size(symbol: "EUR/USD").plans
    expect(plans["buy"].to_h.slice(:entry, :stop, :target)).to eq(entry: BigDecimal("1.12"), stop: BigDecimal("1.116"), target: BigDecimal("1.128"))
    expect(plans["sell"].to_h.slice(:entry, :stop, :target)).to eq(entry: BigDecimal("1.12"), stop: BigDecimal("1.124"), target: BigDecimal("1.112"))
  end

  it "prices JPY pips through the pair's own rate and rounds down to the lot step" do
    result = size(symbol: "USD/JPY")
    # US$ pip value per lot = 0.01 * 100,000 / 150 = US$6.67; 12 / (40 * 6.67) = 0.0450
    expect(result.steps[2]).to eq("With a 40-pip stop and a USD/JPY standard-lot pip value of US$6.67 at USD/JPY 150:")
    expect(result.lots).to eq(BigDecimal("0.04"))
    expect(result.steps).to include("Rounded down to your 0.01 lot step: 0.04 lots")
    expect(result.risk_at_size).to be <= result.planned_risk
  end

  it "follows the saved stop distance, fixed risk and maximum loss" do
    profile.update!(stop_pips: 20, mode: "fixed", fixed_risk: 15)
    expect(size(symbol: "EUR/USD").lots).to eq(BigDecimal("0.04"))
    profile.update!(max_loss: 12)
    result = size(symbol: "EUR/USD")
    expect(result.planned_risk).to eq(12)
    expect(result.steps.first).to end_with("(capped by your maximum loss)")
  end

  it "asks for a price or NZD/USD rate only when none is stored" do
    expect(size(symbol: "GBP/USD").errors).to eq([ "No GBP/USD price is stored yet. Enter the current price." ])
    expect(size(symbol: "GBP/USD", entry: "1.30").lots).to eq(BigDecimal("0.03"))
    expect(size(symbol: "EUR/USD", rates: { "EUR/USD" => candle.new(BigDecimal("1.12")) }).errors.first).to start_with("No NZD/USD rate")
    expect(size(symbol: "EUR/USD", rates: { "EUR/USD" => candle.new(BigDecimal("1.12")) }, nzd_usd: "0.6").lots).to eq(BigDecimal("0.03"))
    expect(size(symbol: "NZD/USD", entry: "0.60", rates: {}).sources).to eq([ "NZD/USD 0.6 (entry price)" ])
  end

  it "explains small balances, missing accounts and bad input" do
    expect(size(balance: BigDecimal("100"), symbol: "EUR/USD").errors.first).to start_with("The position would be")
    expect(size(balance: BigDecimal("0"), symbol: "EUR/USD").errors.first).to start_with("Set up the account")
    expect(size(symbol: "GBP/USD", entry: "abc").errors).to eq([ "Prices must be numbers, for example 1.12025" ])
  end
end
