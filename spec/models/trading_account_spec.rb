require "rails_helper"

RSpec.describe TradingAccount do
  let(:user) { User.create!(email_address: "owner@example.com", password: "correct horse battery") }
  let(:account) { user.create_trading_account!(starting_capital: 2000, started_at: Time.current) }

  def entry(kind, amount)
    account.ledger_entries.create!(kind: kind, amount: amount, effective_at: Time.current)
  end

  it "computes balance from capital and cash movements" do
    entry("deposit", 100)
    entry("withdrawal", -30)
    entry("adjustment", 50)
    entry("adjustment", -20)
    expect(account.balance).to eq(2100)
    expect(account.totals).to eq(deposits: 100, withdrawals: -30, adjustments: 30)
  end

  it "keeps entries immutable and corrects them with an exact reversal" do
    deposit = entry("deposit", 100)
    expect { deposit.update!(amount: 200) }.to raise_error(ActiveRecord::ReadOnlyRecord)
    expect { deposit.destroy }.to raise_error(ActiveRecord::ReadOnlyRecord)
    deposit.reload.reverse!
    expect(account.balance).to eq(2000)
    expect(deposit.reload).not_to be_reversible
    expect { deposit.reverse! }.to raise_error(ActiveRecord::RecordInvalid)
  end

  it "rejects wrong signs and withdrawals beyond the balance" do
    expect { entry("deposit", -5) }.to raise_error(ActiveRecord::RecordInvalid)
    expect { entry("withdrawal", 5) }.to raise_error(ActiveRecord::RecordInvalid)
    expect { entry("withdrawal", -2500) }.to raise_error(ActiveRecord::RecordInvalid, /exceeds the current balance/)
  end

  it "does not allow changing starting capital after creation" do
    expect { account.update!(starting_capital: 5000) }.to raise_error(ActiveRecord::ReadonlyAttributeError)
    expect(account.reload.starting_capital).to eq(2000)
  end
end
