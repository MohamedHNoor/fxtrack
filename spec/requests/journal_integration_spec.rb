require "rails_helper"

RSpec.describe "Journal on the account, dashboard and signal pages" do
  let!(:owner) { User.create!(email_address: "owner@example.com", password: "correct horse battery") }
  let!(:account) { owner.create_trading_account!(starting_capital: 2000, started_at: Time.utc(2026, 9, 1)) }

  before { post login_path, params: { email_address: owner.email_address, password: "correct horse battery" } }

  def closed_trade(**attrs)
    JournalTrade.new(trading_account: account).record!({ symbol: "EUR/USD", direction: "buy", status: "taken", opened_at: 3.hours.ago,
      entry_price: "1.10000", units: "10000", exit_price: "1.10290", closed_at: 1.hour.ago, closing_rate: "0.58" }.merge(attrs), actor: owner)
  end

  it "shows closed-trade P&L on the account page without a manual reversal" do
    trade = closed_trade
    account.ledger_entries.create!(kind: "deposit", amount: 100, effective_at: Time.current)
    get account_path
    expect(response.body).to include("NZD 2,150.00", "+NZD 50.00", "Trade P&amp;L", journal_trade_path(trade), "Not included (open trades)")
    expect(response.body.scan("Reverse</button>").size).to eq(1)

    posting = account.ledger_entries.find_by!(kind: "trade")
    post ledger_entry_reversal_path(posting)
    expect(response).to redirect_to(account_path)
    follow_redirect!
    expect(response.body).to include("That entry cannot be reversed.")
    expect(account.reload.balance).to eq(2150)
  end

  it "labels a corrected posting and keeps totals attributable" do
    trade = closed_trade
    trade.record!({ exit_price: "1.10116" }, actor: owner, reason: "Wrong exit")
    get account_path
    expect(response.body).to include("Trade P&amp;L correction", "+NZD 20.00", "NZD 2,020.00")
    expect(account.totals).to include(closed_trade_pnl: 20, adjustments: 0)
  end

  it "shows decorative icons and the phone quick navigation with the current page marked" do
    get journal_trades_path
    expect(response.body).to include('<span aria-hidden="true" class="w-4 text-center">▤</span>Journal', 'aria-label="Quick navigation"')
    quick = response.body[/<nav aria-label="Quick navigation".*?<\/nav>/m]
    expect(quick.scan(/href="([^"]+)"/).flatten).to eq([ dashboard_path, signals_path, journal_trades_path, settings_path ])
    expect(quick).to match(/aria-current="page"[^>]*href="#{journal_trades_path}"|href="#{journal_trades_path}"[^>]*aria-current="page"/)
  end

  it "shows recent journal records or an empty state on the dashboard" do
    get dashboard_path
    expect(response.body).to include("Recent journal", "No trades recorded yet", new_journal_trade_path)
    closed_trade
    get dashboard_path
    expect(response.body).to include("Recent journal", "EUR/USD", "+NZD 50.00", "Closed")
  end

  it "links a signal to a new or existing journal record" do
    signal = journal_signal(owner)
    get signal_path(signal)
    expect(response.body).to include("Record in journal", new_journal_trade_path(signal_id: signal.id))
    trade = JournalTrade.new(trading_account: account).record!({ trade_signal: signal, symbol: "EUR/USD", direction: "buy", status: "skipped",
      skipped_at: Time.current }, actor: owner)
    get signal_path(signal)
    expect(response.body).to include("View journal record", journal_trade_path(trade))
  end
end
