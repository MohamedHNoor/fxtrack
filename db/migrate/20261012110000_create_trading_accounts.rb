class CreateTradingAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :trading_accounts do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.string :currency, null: false, default: "NZD"
      t.decimal :starting_capital, precision: 14, scale: 2, null: false
      t.datetime :started_at, null: false
      t.timestamps
    end
    add_check_constraint :trading_accounts, "currency = 'NZD'", name: "trading_account_currency_nzd"
    add_check_constraint :trading_accounts, "starting_capital >= 0", name: "trading_account_capital_nonnegative"
  end
end
