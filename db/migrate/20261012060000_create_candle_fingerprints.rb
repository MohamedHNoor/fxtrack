class CreateCandleFingerprints < ActiveRecord::Migration[8.1]
  def change
    # Keyed OHLC digests let later requests prove closed candles are reproducible
    # without retaining provider prices before storage rights are resolved.
    create_table :candle_fingerprints do |t|
      t.references :provider_request, null: false, foreign_key: true
      t.string :symbol, null: false
      t.string :interval, null: false
      t.datetime :opened_at, null: false
      t.string :digest, null: false
      t.timestamps
    end
    add_index :candle_fingerprints, [ :symbol, :interval, :opened_at ], unique: true
    add_check_constraint :candle_fingerprints, "interval IN ('1h', '4h')", name: "candle_fingerprint_interval"
    add_check_constraint :candle_fingerprints, "digest ~ '^[0-9a-f]{64}$'", name: "candle_fingerprint_digest"

    change_table :data_quality_metrics, bulk: true do |t|
      t.integer :reproduced_count, null: false, default: 0
      t.integer :mismatch_count, null: false, default: 0
    end
    add_check_constraint :data_quality_metrics, "reproduced_count >= 0 AND mismatch_count >= 0", name: "quality_reproduction_nonnegative"
  end
end
