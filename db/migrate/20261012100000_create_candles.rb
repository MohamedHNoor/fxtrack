class CreateCandles < ActiveRecord::Migration[8.1]
  def change
    # Observed Twelve Data forex prices carry up to 5 decimals (3 for JPY pairs);
    # scale 8 leaves headroom without floating-point storage.
    create_table :candles do |t|
      t.references :provider_request, null: false, foreign_key: true
      t.string :symbol, null: false
      t.string :interval, null: false
      t.datetime :opened_at, null: false
      t.decimal :open, precision: 16, scale: 8, null: false
      t.decimal :high, precision: 16, scale: 8, null: false
      t.decimal :low, precision: 16, scale: 8, null: false
      t.decimal :close, precision: 16, scale: 8, null: false
      t.timestamps
    end
    add_index :candles, [ :symbol, :interval, :opened_at ], unique: true
    add_check_constraint :candles, "interval IN ('1h', '4h')", name: "candle_interval"
    add_check_constraint :candles, "low > 0 AND low <= LEAST(open, close) AND high >= GREATEST(open, close)", name: "candle_ohlc_consistent"
  end
end
