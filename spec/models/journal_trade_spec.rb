require "rails_helper"

RSpec.describe JournalTrade do
  let(:owner) { User.create!(email_address: "owner@example.com", password: "correct horse battery") }
  let(:account) { owner.create_trading_account!(starting_capital: 2000, started_at: Time.utc(2026, 9, 1)) }
  let(:now) { Time.utc(2026, 10, 12, 3) }

  around { |example| travel_to(now) { example.run } }

  def record(trade = JournalTrade.new(trading_account: account), reason: nil, **attrs)
    trade.record!(attrs, actor: owner, reason: reason)
  end

  def open_trade(**attrs)
    record(symbol: "EUR/USD", direction: "buy", status: "taken", opened_at: now - 5.hours, entry_price: "1.10000", units: "10000", **attrs)
  end

  def closing(**attrs)
    { exit_price: "1.10500", closed_at: now - 1.hour, closing_rate: "0.5800" }.merge(attrs)
  end

  describe ".calculate_pnl" do
    it "converts quote P&L at a quote-per-NZD rate, nets NZD costs and rounds half up once" do
      expect(described_class.calculate_pnl(direction: "buy", entry: BigDecimal("1.1"), exit: BigDecimal("1.105"), units: 10_000,
        rate: BigDecimal("0.58"), fees: BigDecimal("1.5"), financing: BigDecimal("-0.3"))).to eq(BigDecimal("84.41"))
      expect(described_class.calculate_pnl(direction: "sell", entry: BigDecimal("150"), exit: BigDecimal("149.5"), units: 20_000,
        rate: BigDecimal("88.5"), fees: 0, financing: 0)).to eq(BigDecimal("112.99"))
      expect(described_class.calculate_pnl(direction: "buy", entry: BigDecimal("1"), exit: BigDecimal("1.0000125"), units: 10_000,
        rate: 1, fees: 0, financing: 0)).to eq(BigDecimal("0.13"))
    end
  end

  it "keeps an open trade out of the balance and posts realized P&L when it closes" do
    trade = open_trade(fees_nzd: "1.50", financing_nzd: "-0.30")
    expect([ trade.state, trade.realized_pnl_nzd, trade.pnl_source ]).to eq([ "open", nil, "none" ])
    expect(account.balance).to eq(2000)

    record(trade, **closing)
    expect([ trade.state, trade.calculated_pnl_nzd, trade.realized_pnl_nzd, trade.pnl_source ]).to eq([ "closed", 84.41, 84.41, "calculated" ])
    expect(account.ledger_entries.pluck(:kind, :amount, :effective_at, :journal_trade_id)).to eq([ [ "trade", 84.41, now - 1.hour, trade.id ] ])
    expect(account.balance).to eq(BigDecimal("2084.41"))
    expect(account.totals).to include(closed_trade_pnl: 84.41, adjustments: 0)
  end

  it "prefers an explained manual override while keeping the calculated amount" do
    trade = open_trade(**closing, override_pnl_nzd: "80", override_reason: "Broker statement")
    expect([ trade.calculated_pnl_nzd, trade.realized_pnl_nzd, trade.pnl_source ]).to eq([ BigDecimal("86.21"), 80, "override" ])
    expect(account.balance).to eq(2080)

    expect { open_trade(**closing, override_pnl_nzd: "80") }.to raise_error(ActiveRecord::RecordInvalid, /Override reason is required/)
    expect { open_trade(override_pnl_nzd: "80", override_reason: "Early") }.to raise_error(ActiveRecord::RecordInvalid, /needs a closed trade/)
  end

  it "requires every closing field together" do
    expect { open_trade(exit_price: "1.105") }.to raise_error(ActiveRecord::RecordInvalid, /Closed at is required.*Closing rate is required/)
  end

  it "records a skipped decision without fills, P&L or a posting" do
    trade = record(symbol: "GBP/USD", direction: "sell", status: "skipped", skipped_at: now - 2.hours, notes: "News risk")
    expect([ trade.state, trade.realized_pnl_nzd, trade.recorded_at ]).to eq([ "skipped", nil, now - 2.hours ])
    expect(account.ledger_entries).to be_empty

    expect { record(symbol: "GBP/USD", direction: "sell", status: "skipped", skipped_at: now, entry_price: "1.3") }
      .to raise_error(ActiveRecord::RecordInvalid, /Entry price must be blank for a skipped trade/)
    expect { record(symbol: "GBP/USD", direction: "sell", status: "skipped", skipped_at: now, fees_nzd: "2") }
      .to raise_error(ActiveRecord::RecordInvalid, /must be zero for a skipped trade/)
  end

  it "rejects future times, closes before opens and unsupported values" do
    expect { open_trade(opened_at: now + 1.minute) }.to raise_error(ActiveRecord::RecordInvalid, /Opened at cannot be in the future/)
    expect { open_trade(**closing(closed_at: now - 6.hours)) }.to raise_error(ActiveRecord::RecordInvalid, /must be at or after the open time/)
    expect { open_trade(symbol: "EUR/GBP") }.to raise_error(ActiveRecord::RecordInvalid, /Pair is not included/)
    expect { open_trade(units: "0", closing_rate: nil) }.to raise_error(ActiveRecord::RecordInvalid, /Units must be greater than 0/)
  end

  it "links at most one record to a signal with the same pair and direction" do
    signal = journal_signal(owner)
    expect { open_trade(trade_signal: signal, direction: "sell") }.to raise_error(ActiveRecord::RecordInvalid, /Direction must match the signal \(buy\)/)
    open_trade(trade_signal: signal)
    expect { record(trade_signal: signal, symbol: "EUR/USD", direction: "buy", status: "skipped", skipped_at: now) }
      .to raise_error(ActiveRecord::RecordInvalid, /already has a journal record/)
    expect(signal.reload.status).to eq("active")
  end

  it "audits each create and change but not a save without changes" do
    trade = open_trade
    record(trade, notes: "Moved stop")
    record(trade, notes: "Moved stop")
    expect(trade.audit_events.map(&:action)).to eq(%w[created updated])
    expect(trade.audit_events.last.changes_made).to eq("notes" => [ nil, "Moved stop" ])
    expect(trade.audit_events.map(&:user)).to all(eq(owner))
  end

  it "requires a reason to correct a closed trade, then reverses and reposts its P&L once" do
    trade = open_trade(**closing(fees_nzd: "1.50", financing_nzd: "-0.30"))
    expect { record(trade, exit_price: "1.10600") }.to raise_error(ActiveRecord::RecordInvalid, /correction reason is required/)
    expect(trade.reload.exit_price).to eq(BigDecimal("1.105"))

    record(trade, exit_price: "1.10600", reason: "Typo in exit")
    event = trade.audit_events.last
    expect([ event.action, event.reason, event.changes_made.keys ]).to eq([ "corrected", "Typo in exit", %w[exit_price calculated_pnl_nzd] ])
    expect(account.ledger_entries.pluck(:kind, :amount, :effective_at)).to eq(
      [ [ "trade", 84.41, now - 1.hour ], [ "reversal", -84.41, now - 1.hour ], [ "trade", BigDecimal("101.65"), now - 1.hour ] ])
    expect(account.ledger_entries.pluck(:journal_trade_id)).to all(eq(trade.id))
    expect(account.balance).to eq(BigDecimal("2101.65"))
    expect(account.totals).to include(closed_trade_pnl: BigDecimal("101.65"), adjustments: 0)
    expect(trade.reload.corrections_count).to eq(1)

    record(trade, override_pnl_nzd: "100", override_reason: "Statement", reason: "Use statement")
    record(trade, override_pnl_nzd: nil, override_reason: nil, reason: "Statement was wrong")
    expect(account.ledger_entries.where.missing(:reversal).where(kind: "trade").pluck(:amount)).to eq([ BigDecimal("101.65") ])
    expect(account.balance).to eq(BigDecimal("2101.65"))
  end

  it "posts nothing for a breakeven trade" do
    trade = open_trade(**closing(exit_price: "1.10000"))
    expect(trade.realized_pnl_nzd).to eq(0)
    expect(account.ledger_entries).to be_empty
  end

  it "keeps audit events and trade postings immutable and out of manual reversal" do
    trade = open_trade(**closing)
    event = trade.audit_events.first
    posting = account.ledger_entries.sole
    expect { event.update!(reason: "x") }.to raise_error(ActiveRecord::ReadOnlyRecord)
    expect { event.destroy }.to raise_error(ActiveRecord::ReadOnlyRecord)
    expect { posting.update!(amount: 1) }.to raise_error(ActiveRecord::ReadOnlyRecord)
    expect(posting).not_to be_reversible
    expect { account.ledger_entries.create!(kind: "trade", amount: 5, effective_at: now) }.to raise_error(ActiveRecord::RecordInvalid)
    expect { account.ledger_entries.create!(kind: "deposit", amount: 5, effective_at: now, journal_trade: trade) }.to raise_error(ActiveRecord::RecordInvalid)
  end

  it "moves the balance with the cross-feature fixture: 2,000 then a 50 win and a 20 loss" do
    open_trade(**closing(exit_price: "1.10290"))
    expect(account.balance).to eq(2050)
    open_trade(direction: "sell", **closing(exit_price: "1.10116"))
    expect(account.balance).to eq(2030)
  end
end
