require "rails_helper"

RSpec.describe "Account and risk" do
  let!(:owner) { User.create!(email_address: "owner@example.com", password: "correct horse battery") }

  before { post login_path, params: { email_address: owner.email_address, password: "correct horse battery" } }

  def set_up(capital = "2000")
    post account_path, params: { trading_account: { starting_capital: capital, started_at: "2026-10-12T12:00" } }
  end

  def record(kind, amount, **extra)
    post ledger_entries_path, params: { account_ledger_entry: { kind: kind, amount: amount, effective_at: "2026-10-12T13:00", **extra } }
  end

  it "sets up the account once, reading times as New Zealand wall-clock time" do
    set_up
    expect(response).to redirect_to(account_path)
    expect(owner.trading_account.started_at).to eq(Time.utc(2026, 10, 11, 23))
    set_up("5000")
    expect(owner.trading_account.reload.starting_capital).to eq(2000)
  end

  it "records movements with the right signs and reverses mistakes" do
    set_up
    record("deposit", "100")
    record("withdrawal", "30")
    record("adjustment", "20", direction: "decrease")
    account = owner.trading_account
    expect(account.ledger_entries.pluck(:kind, :amount)).to eq([ [ "deposit", 100 ], [ "withdrawal", -30 ], [ "adjustment", -20 ] ])
    expect(account.balance).to eq(2050)

    post ledger_entry_reversal_path(account.ledger_entries.first)
    expect(account.reload.balance).to eq(1950)
    get account_path
    expect(response.body).to include("NZD 1,950.00", "(reversed)")
  end

  it "rejects an overdraft and a direct reversal entry" do
    set_up
    record("withdrawal", "2500")
    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("exceeds the current balance")
    record("reversal", "10")
    expect(response).to have_http_status(:unprocessable_entity)
    expect(owner.trading_account.ledger_entries.count).to eq(0)
  end

  it "calculates a pair's position from the saved risk settings and stored prices" do
    set_up
    request = ProviderRequest.create!(symbol: "NZD/USD", interval: "1h", endpoint: "time_series", requested_at: Time.current, status: "success")
    Candle.create!(provider_request: request, symbol: "NZD/USD", interval: "1h", opened_at: 2.hours.ago.beginning_of_hour,
      open: 0.6, high: 0.601, low: 0.599, close: 0.6)
    get settings_path, params: { trade: { symbol: "NZD/USD" } }
    # NZ$2,000 x 1% = NZ$20 = US$12; 40 pips x US$10 per lot gives 0.03 lots.
    expect(response.body).to include("0.03 lots", "3,000 units", "NZ$20.00", "Buy plan", "Sell plan", "0.59600", "0.60800")

    patch risk_profile_path, params: { risk_profile: { mode: "fixed", fixed_risk: "15", stop_pips: "20" } }
    expect(response).to redirect_to(settings_path)
    get settings_path, params: { trade: { symbol: "NZD/USD" } }
    expect(response.body).to include("Fixed risk per trade: NZ$15.00", "0.04 lots")
    expect(owner.trading_account.balance).to eq(2000)
  end

  it "asks for a price when the pair has none stored" do
    set_up
    get settings_path, params: { trade: { symbol: "GBP/USD" } }
    expect(response.body).to include("No GBP/USD price is stored yet", "Current GBP/USD price")
  end

  it "shows the risk and account settings page and redirects the old risk path" do
    set_up
    get settings_path
    expect(response.body).to include("Risk &amp; account settings", "Risk management", "Capital management", "Currency pair preferences", "Position calculator", "Planned risk per trade")
    get "/risk"
    expect(response).to redirect_to("/settings")
  end

  it "does not save risk settings just by viewing them" do
    expect { get settings_path }.not_to change(RiskProfile, :count)
  end

  it "rejects invalid risk settings" do
    patch risk_profile_path, params: { risk_profile: { risk_percent: "25" } }
    expect(response).to have_http_status(:unprocessable_entity)
  end
end
