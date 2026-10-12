require "rails_helper"

RSpec.describe "Trading journal" do
  let!(:owner) { User.create!(email_address: "owner@example.com", password: "correct horse battery") }
  let(:now) { Time.utc(2026, 10, 12, 3) }

  around { |example| travel_to(now) { example.run } }

  def log_in
    post login_path, params: { email_address: owner.email_address, password: "correct horse battery" }
  end

  def set_up_account
    owner.create_trading_account!(starting_capital: 2000, started_at: Time.utc(2026, 9, 1))
  end

  # Times are New Zealand wall-clock: 13:00 NZDT is 00:00 UTC on 12 October.
  def taken_params(**overrides)
    { status: "taken", symbol: "EUR/USD", direction: "buy", opened_at: "2026-10-12T11:00", entry_price: "1.10000", units: "10000",
      closed_at: "", exit_price: "", closing_rate: "", fees_nzd: "", financing_nzd: "", override_pnl_nzd: "", override_reason: "", notes: "" }.merge(overrides)
  end

  def closing_params(**overrides)
    { closed_at: "2026-10-12T15:00", exit_price: "1.10500", closing_rate: "0.5800", fees_nzd: "1.50", financing_nzd: "-0.30" }.merge(overrides)
  end

  it "requires login for every journal page" do
    get journal_trades_path
    expect(response).to redirect_to(login_path)
    get journal_trades_path(format: :csv)
    expect(response).to redirect_to(login_path)
    post journal_trades_path, params: { journal_trade: taken_params }
    expect(response).to redirect_to(login_path)
    expect(JournalTrade.count).to eq(0)
  end

  context "when logged in" do
    before { log_in }

    it "sends the owner to set up the account first" do
      get journal_trades_path
      expect(response).to redirect_to(account_path)
      follow_redirect!
      expect(response.body).to include("Set up the account first.")
    end

    context "with an account" do
      let!(:account) { set_up_account }

      it "shows an empty journal and returns 404 for an unknown record" do
        get journal_trades_path
        expect(response.body).to include("Trading Journal", "No journal records yet", "Account balance", "Open trades", "+ Record trade")
        get journal_trade_path(id: 999_999)
        expect(response).to have_http_status(:not_found)
      end

      it "records an open trade, closes it and posts the realized P&L to the ledger" do
        post journal_trades_path, params: { journal_trade: taken_params }
        trade = JournalTrade.sole
        expect(response).to redirect_to(journal_trade_path(trade))
        expect([ trade.state, trade.opened_at, trade.fees_nzd ]).to eq([ "open", Time.utc(2026, 10, 11, 22), 0 ])
        expect(account.balance).to eq(2000)

        patch journal_trade_path(trade), params: { journal_trade: taken_params(**closing_params).except(:status) }
        expect(response).to redirect_to(journal_trade_path(trade))
        expect(trade.reload.realized_pnl_nzd).to eq(BigDecimal("84.41"))
        expect(account.reload.balance).to eq(BigDecimal("2084.41"))
        get journal_trade_path(trade)
        expect(response.body).to include("+NZD 84.41", "Source: <strong>Calculated</strong>", "Created", "Updated", "Exit price: blank → 1.105",
          "Closed at: blank → 12 Oct 2026, 15:00 NZDT")

        get journal_trades_path
        expect(response.body).to include("EUR/USD", "Closed 2026-10-12", "+84.41", "+NZD 84.41", "Closed trades")
        expect(response.body.scan("Journal record updated.").size).to eq(0)
        patch journal_trade_path(trade), params: { journal_trade: taken_params(**closing_params(notes: "x")).except(:status), correction_reason: "Note" }
        follow_redirect!
        expect(response.body.scan("Journal record updated.").size).to eq(1)
        expect(response.body).to include("motion-settle")
      end

      it "records a skipped decision without fills" do
        post journal_trades_path, params: { journal_trade: taken_params(status: "skipped", skipped_at: "2026-10-12T12:00", notes: "Spread too wide") }
        trade = JournalTrade.sole
        expect([ trade.state, trade.entry_price, trade.opened_at ]).to eq([ "skipped", nil, nil ])
        expect(account.ledger_entries).to be_empty
        get journal_trade_path(trade)
        expect(response.body).to include("Skipped", "Spread too wide")
      end

      it "re-renders invalid input with the error summary and the entered values" do
        post journal_trades_path, params: { journal_trade: taken_params(entry_price: "", units: "2500", closing_rate: "0.58") }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include('role="alert"', "Entry price can&#39;t be blank", "Closed at is required to close the trade", 'value="2500.0"')
        expect(JournalTrade.count).to eq(0)
      end

      it "requires a reason to correct a closed trade and shows overrides beside the calculation" do
        post journal_trades_path, params: { journal_trade: taken_params(**closing_params) }
        trade = JournalTrade.sole
        get edit_journal_trade_path(trade)
        expect(response.body).to include("Correction reason")

        corrected = taken_params(**closing_params(override_pnl_nzd: "80", override_reason: "Broker statement")).except(:status)
        patch journal_trade_path(trade), params: { journal_trade: corrected }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("A correction reason is required to change a closed trade")
        expect(trade.reload.override_pnl_nzd).to be_nil

        patch journal_trade_path(trade), params: { journal_trade: corrected, correction_reason: "Matched statement" }
        expect(account.reload.balance).to eq(2080)
        get journal_trade_path(trade)
        expect(response.body).to include("Manual override", "+NZD 80.00", "+NZD 84.41", "Broker statement", "Corrected", "Reason: Matched statement")
      end

      it "prefills from an owner signal, links it once and leaves the signal unchanged" do
        signal = journal_signal(owner)
        get new_journal_trade_path(signal_id: signal.id)
        expect(response.body).to include("Record Actual Trade", "Manual trade record", 'data-controller="journal-form"', "From signal: EUR/USD", "Planned entry", "1.10000", %(value="#{signal.id}"))

        post journal_trades_path, params: { journal_trade: taken_params(trade_signal_id: signal.id) }
        trade = JournalTrade.sole
        expect(trade.trade_signal).to eq(signal)
        expect(signal.reload.status).to eq("active")
        get new_journal_trade_path(signal_id: signal.id)
        expect(response).to redirect_to(journal_trade_path(trade))

        get new_journal_trade_path(signal_id: 999_999)
        expect(response).to have_http_status(:not_found)
      end

      describe "filters and CSV export" do
        let!(:strategy) { journal_signal(owner, symbol: "GBP/USD", direction: "sell").strategy_version.strategy }
        let!(:open_eur) { record(symbol: "EUR/USD", direction: "buy", status: "taken", opened_at: Time.utc(2026, 10, 10, 1), entry_price: "1.1", units: "10000") }
        let!(:closed_gbp) do
          record(symbol: "GBP/USD", direction: "sell", status: "taken", opened_at: Time.utc(2026, 10, 11, 1), entry_price: "1.3", units: "5000",
            exit_price: "1.29", closed_at: Time.utc(2026, 10, 11, 5), closing_rate: "0.58", override_pnl_nzd: "85", override_reason: "=HYPERLINK(1)",
            trade_signal: TradeSignal.sole, notes: "@cmd")
        end
        let!(:skipped_jpy) { record(symbol: "USD/JPY", direction: "buy", status: "skipped", skipped_at: Time.utc(2026, 10, 11, 23), notes: "Plain note") }

        def record(**attrs)
          JournalTrade.new(trading_account: account).record!(attrs, actor: owner)
        end

        def listed(**filters)
          get journal_trades_path(format: :csv, **filters)
          CSV.parse(response.body, headers: true).map { |row| row["id"].to_i }
        end

        it "filters by pair, state, strategy and New Zealand dates, ignoring invalid values" do
          expect(listed).to eq([ skipped_jpy.id, closed_gbp.id, open_eur.id ])
          expect(listed(pair: "GBP/USD")).to eq([ closed_gbp.id ])
          expect(listed(state: "open")).to eq([ open_eur.id ])
          expect(listed(state: "closed")).to eq([ closed_gbp.id ])
          expect(listed(state: "skipped")).to eq([ skipped_jpy.id ])
          expect(listed(strategy: strategy.id)).to eq([ closed_gbp.id ])
          expect(listed(strategy: "manual")).to eq([ skipped_jpy.id, open_eur.id ])
          # 23:00 UTC on 11 October is 12 October in New Zealand.
          expect(listed(from: "2026-10-12")).to eq([ skipped_jpy.id ])
          expect(listed(from: "2026-10-10", to: "2026-10-11")).to eq([ closed_gbp.id, open_eur.id ])
          expect(listed(pair: "EUR/USD", state: "closed")).to eq([])
          expect(listed(pair: "XAU/USD", state: "bogus", strategy: "0", from: "not-a-date")).to eq([ skipped_jpy.id, closed_gbp.id, open_eur.id ])

          get journal_trades_path(pair: "XAU/USD", state: "closed", from: "nope")
          expect(response.body).to include('<option selected="selected" value="closed">', "Export CSV")
          expect(response.body).not_to include("XAU/USD", "nope")
          get journal_trades_path(pair: "NZD/USD")
          expect(response.body).to include("No records match these filters.")

          audit_queries = []
          counter = ->(*, payload) { audit_queries << payload[:sql] if payload[:sql].include?("audit_events") }
          ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { get journal_trades_path }
          expect(audit_queries).to be_empty
        end

        it "exports the journal as a CSV attachment with neutralized text cells" do
          audit_queries = []
          counter = ->(*, payload) { audit_queries << payload[:sql] if payload[:sql].include?("audit_events") }
          ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { get journal_trades_path(format: :csv) }
          expect(audit_queries.size).to eq(1)
          expect(response.media_type).to eq("text/csv")
          expect(response.headers["Content-Disposition"]).to include("attachment", "fxtrack-journal-20261012.csv")
          rows = CSV.parse(response.body, headers: true)
          expect(rows.headers).to eq(JournalTrade::CSV_HEADERS)

          gbp = rows.find { |row| row["id"] == closed_gbp.id.to_s }
          expect(gbp.to_h.slice("state", "pair", "direction", "signal_id", "strategy", "opened_at", "closed_at", "entry_price", "units", "lots",
            "closing_rate_quote_per_nzd", "calculated_pnl_nzd", "override_pnl_nzd", "realized_pnl_nzd", "pnl_source", "override_reason", "notes", "corrections"))
            .to eq("state" => "closed", "pair" => "GBP/USD", "direction" => "sell", "signal_id" => TradeSignal.sole.id.to_s,
              "strategy" => strategy.name, "opened_at" => "2026-10-11T14:00:00+13:00", "closed_at" => "2026-10-11T18:00:00+13:00",
              "entry_price" => "1.3", "units" => "5000.0", "lots" => "0.05", "closing_rate_quote_per_nzd" => "0.58",
              "calculated_pnl_nzd" => "86.21", "override_pnl_nzd" => "85.0", "realized_pnl_nzd" => "85.0", "pnl_source" => "override",
              "override_reason" => "'=HYPERLINK(1)", "notes" => "'@cmd", "corrections" => "0")

          eur = rows.find { |row| row["id"] == open_eur.id.to_s }
          expect(eur.to_h.slice("state", "closed_at", "realized_pnl_nzd", "pnl_source", "fees_nzd")).to eq(
            "state" => "open", "closed_at" => nil, "realized_pnl_nzd" => nil, "pnl_source" => "none", "fees_nzd" => "0.0")
          jpy = rows.find { |row| row["id"] == skipped_jpy.id.to_s }
          expect(jpy.to_h.slice("state", "skipped_at", "entry_price", "notes")).to eq(
            "state" => "skipped", "skipped_at" => "2026-10-12T12:00:00+13:00", "entry_price" => nil, "notes" => "Plain note")
        end
      end

      it "re-renders out-of-range numbers, unparseable times and duplicate signal links as 422" do
        post journal_trades_path, params: { journal_trade: taken_params(entry_price: "1000000000") }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("Entry price must be less than 100000000")

        post journal_trades_path, params: { journal_trade: taken_params(units: "999999999999", entry_price: "1", **closing_params(exit_price: "99999999", closing_rate: "0.00000001")) }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("The calculated P&amp;L is too large to record")

        post journal_trades_path, params: { journal_trade: taken_params(**closing_params(closed_at: "2026-13-01T10:00")) }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("Closed at is not a valid date and time")
        expect(JournalTrade.count).to eq(0)

        signal = journal_signal(owner)
        allow_any_instance_of(JournalTrade).to receive(:record!).and_raise(ActiveRecord::RecordNotUnique)
        post journal_trades_path, params: { journal_trade: taken_params(trade_signal_id: signal.id) }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("Signal already has a journal record")
      end

      it "escapes owner-entered text" do
        post journal_trades_path, params: { journal_trade: taken_params(notes: "<script>alert(1)</script>") }
        get journal_trade_path(JournalTrade.sole)
        expect(response.body).to include("&lt;script&gt;alert(1)&lt;/script&gt;")
        expect(response.body).not_to include("<script>alert(1)</script>")
      end
    end
  end
end
