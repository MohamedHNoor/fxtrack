require "rails_helper"

RSpec.describe "Concurrent withdrawals" do
  self.use_transactional_tests = false

  it "serializes withdrawals against the same available balance" do
    user = User.create!(email_address: "owner@example.com", password: "correct horse battery")
    account = user.create_trading_account!(starting_capital: 100, started_at: Time.current)
    ready, start = Queue.new, Queue.new
    threads = 2.times.map do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          own_account = TradingAccount.find(account.id)
          ready << true
          start.pop
          own_account.ledger_entries.create!(kind: "withdrawal", amount: -75, effective_at: Time.current)
          :saved
        rescue ActiveRecord::RecordInvalid
          :rejected
        end
      end
    end
    2.times { ready.pop }
    2.times { start << true }
    expect(threads.map(&:value).sort).to eq([ :rejected, :saved ])
    expect(account.balance).to eq(25)
  ensure
    threads&.each(&:join)
    AccountLedgerEntry.where(trading_account_id: account.id).delete_all if account
    TradingAccount.where(id: account.id).delete_all if account
    User.where(id: user.id).delete_all if user
  end
end
