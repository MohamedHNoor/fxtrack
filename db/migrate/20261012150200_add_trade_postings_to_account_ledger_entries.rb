# Closed journal trades post their realized NZD P&L to the ledger. A reversal
# of a trade posting carries the same journal trade so totals stay attributable.
class AddTradePostingsToAccountLedgerEntries < ActiveRecord::Migration[8.1]
  def up
    add_reference :account_ledger_entries, :journal_trade, foreign_key: true
    remove_check_constraint :account_ledger_entries, name: "ledger_kind"
    remove_check_constraint :account_ledger_entries, name: "ledger_amount_sign"
    add_check_constraint :account_ledger_entries, "kind IN ('deposit', 'withdrawal', 'adjustment', 'reversal', 'trade')", name: "ledger_kind"
    add_check_constraint :account_ledger_entries,
      "(kind = 'deposit' AND amount > 0) OR (kind = 'withdrawal' AND amount < 0) OR (kind IN ('adjustment', 'reversal', 'trade') AND amount <> 0)",
      name: "ledger_amount_sign"
    add_check_constraint :account_ledger_entries,
      "(kind = 'trade' AND journal_trade_id IS NOT NULL) OR (kind IN ('deposit', 'withdrawal', 'adjustment') AND journal_trade_id IS NULL) OR kind = 'reversal'",
      name: "ledger_trade_link"
  end

  def down
    remove_check_constraint :account_ledger_entries, name: "ledger_trade_link"
    remove_check_constraint :account_ledger_entries, name: "ledger_amount_sign"
    remove_check_constraint :account_ledger_entries, name: "ledger_kind"
    add_check_constraint :account_ledger_entries, "kind IN ('deposit', 'withdrawal', 'adjustment', 'reversal')", name: "ledger_kind"
    add_check_constraint :account_ledger_entries,
      "(kind = 'deposit' AND amount > 0) OR (kind = 'withdrawal' AND amount < 0) OR (kind IN ('adjustment', 'reversal') AND amount <> 0)",
      name: "ledger_amount_sign"
    remove_reference :account_ledger_entries, :journal_trade, foreign_key: true
  end
end
