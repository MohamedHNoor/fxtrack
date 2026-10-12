class CreateJournalTrades < ActiveRecord::Migration[8.1]
  def change
    create_table :journal_trades do |t|
      t.references :trading_account, null: false, foreign_key: true
      t.references :trade_signal, foreign_key: true, index: { unique: true }
      t.string :symbol, null: false
      t.string :direction, null: false
      t.string :status, null: false
      t.datetime :opened_at
      t.datetime :skipped_at
      t.decimal :entry_price, precision: 16, scale: 8
      t.decimal :units, precision: 14, scale: 2
      t.decimal :exit_price, precision: 16, scale: 8
      t.datetime :closed_at
      t.decimal :closing_rate, precision: 16, scale: 8
      t.decimal :fees_nzd, precision: 14, scale: 2, null: false, default: 0
      t.decimal :financing_nzd, precision: 14, scale: 2, null: false, default: 0
      t.decimal :calculated_pnl_nzd, precision: 14, scale: 2
      t.decimal :override_pnl_nzd, precision: 14, scale: 2
      t.string :override_reason, limit: 500
      t.text :notes
      t.timestamps
    end

    add_check_constraint :journal_trades, "status IN ('taken', 'skipped')", name: "journal_status"
    add_check_constraint :journal_trades, "direction IN ('buy', 'sell')", name: "journal_direction"
    add_check_constraint :journal_trades,
      "(status = 'taken' AND opened_at IS NOT NULL AND entry_price > 0 AND units > 0 AND skipped_at IS NULL) OR " \
      "(status = 'skipped' AND skipped_at IS NOT NULL AND opened_at IS NULL AND entry_price IS NULL AND units IS NULL " \
      "AND closed_at IS NULL AND fees_nzd = 0 AND financing_nzd = 0)",
      name: "journal_status_fields"
    add_check_constraint :journal_trades,
      "(closed_at IS NULL AND exit_price IS NULL AND closing_rate IS NULL AND calculated_pnl_nzd IS NULL) OR " \
      "(closed_at IS NOT NULL AND exit_price > 0 AND closing_rate > 0 AND calculated_pnl_nzd IS NOT NULL AND closed_at >= opened_at)",
      name: "journal_closing_fields"
    add_check_constraint :journal_trades,
      "(override_pnl_nzd IS NULL AND override_reason IS NULL) OR (override_pnl_nzd IS NOT NULL AND override_reason IS NOT NULL AND closed_at IS NOT NULL)",
      name: "journal_override"
    add_check_constraint :journal_trades, "fees_nzd >= 0", name: "journal_fees_nonnegative"
  end
end
