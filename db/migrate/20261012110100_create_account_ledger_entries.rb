class CreateAccountLedgerEntries < ActiveRecord::Migration[8.1]
  def up
    create_table :account_ledger_entries do |t|
      t.references :trading_account, null: false, foreign_key: true
      t.string :kind, null: false
      t.decimal :amount, precision: 14, scale: 2, null: false
      t.datetime :effective_at, null: false
      t.text :notes
      t.references :reverses_entry, foreign_key: { to_table: :account_ledger_entries }, index: { unique: true }
      t.timestamps
    end
    add_check_constraint :account_ledger_entries, "kind IN ('deposit', 'withdrawal', 'adjustment', 'reversal')", name: "ledger_kind"
    add_check_constraint :account_ledger_entries,
      "(kind = 'deposit' AND amount > 0) OR (kind = 'withdrawal' AND amount < 0) OR (kind IN ('adjustment', 'reversal') AND amount <> 0)",
      name: "ledger_amount_sign"
    add_check_constraint :account_ledger_entries, "(kind = 'reversal') = (reverses_entry_id IS NOT NULL)", name: "ledger_reversal_link"
  end

  def down
    drop_table :account_ledger_entries
  end
end
