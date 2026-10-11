class CreateStrategies < ActiveRecord::Migration[8.1]
  def change
    create_table :strategies do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.string :kind, null: false
      t.boolean :enabled, null: false, default: true
      t.datetime :archived_at
      t.timestamps
    end
    add_index :strategies, [ :user_id, :name ], unique: true
    add_check_constraint :strategies, "kind IN ('trend_pullback')", name: "strategy_kind"

    create_table :strategy_versions do |t|
      t.references :strategy, null: false, foreign_key: true
      t.integer :number, null: false
      t.jsonb :config, null: false, default: {}
      t.timestamps
    end
    add_index :strategy_versions, [ :strategy_id, :number ], unique: true

    create_table :strategy_runs do |t|
      t.references :strategy_version, null: false, foreign_key: true
      t.string :symbol, null: false
      t.datetime :candle_opened_at, null: false
      t.string :verdict, null: false
      t.jsonb :explanation, null: false, default: {}
      t.datetime :evaluated_at, null: false
      t.timestamps
    end
    add_index :strategy_runs, [ :strategy_version_id, :symbol, :candle_opened_at ], unique: true, name: "index_strategy_runs_once_per_candle"
    add_check_constraint :strategy_runs, "verdict IN ('buy', 'sell', 'wait')", name: "strategy_run_verdict"

    create_table :trade_signals do |t|
      t.references :strategy_version, null: false, foreign_key: true
      t.references :strategy_run, null: false, foreign_key: true, index: { unique: true }
      t.string :symbol, null: false
      t.string :direction, null: false
      t.string :status, null: false, default: "active"
      t.datetime :source_opened_at, null: false
      t.decimal :entry, precision: 16, scale: 8, null: false
      t.decimal :stop, precision: 16, scale: 8, null: false
      t.decimal :target, precision: 16, scale: 8, null: false
      t.decimal :entry_tolerance, precision: 16, scale: 8, null: false
      t.decimal :reward_ratio, precision: 5, scale: 2, null: false
      t.decimal :stop_pips, precision: 8, scale: 1, null: false
      t.decimal :planned_risk, precision: 12, scale: 2
      t.decimal :lots, precision: 8, scale: 2
      t.decimal :risk_at_size, precision: 12, scale: 2
      t.string :sizing_error
      t.jsonb :evidence, null: false, default: {}
      t.datetime :generated_at, null: false
      t.datetime :expires_at, null: false
      t.string :status_reason
      t.datetime :status_changed_at
      t.timestamps
    end
    # One signal per strategy version, pair and source candle: duplicates are impossible.
    add_index :trade_signals, [ :strategy_version_id, :symbol, :source_opened_at ], unique: true, name: "index_trade_signals_once_per_candle"
    add_index :trade_signals, :status
    add_check_constraint :trade_signals, "direction IN ('buy', 'sell')", name: "signal_direction"
    add_check_constraint :trade_signals, "status IN ('active', 'invalidated', 'expired', 'completed')", name: "signal_status"
    add_check_constraint :trade_signals, "(direction = 'buy' AND stop < entry AND target > entry) OR (direction = 'sell' AND stop > entry AND target < entry)", name: "signal_levels_direction"
  end
end
