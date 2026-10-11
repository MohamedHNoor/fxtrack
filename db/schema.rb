# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_12_120000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "account_ledger_entries", force: :cascade do |t|
    t.bigint "trading_account_id", null: false
    t.string "kind", null: false
    t.decimal "amount", precision: 14, scale: 2, null: false
    t.datetime "effective_at", null: false
    t.text "notes"
    t.bigint "reverses_entry_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["reverses_entry_id"], name: "index_account_ledger_entries_on_reverses_entry_id", unique: true
    t.index ["trading_account_id"], name: "index_account_ledger_entries_on_trading_account_id"
    t.check_constraint "(kind::text = 'reversal'::text) = (reverses_entry_id IS NOT NULL)", name: "ledger_reversal_link"
    t.check_constraint "kind::text = 'deposit'::text AND amount > 0::numeric OR kind::text = 'withdrawal'::text AND amount < 0::numeric OR (kind::text = ANY (ARRAY['adjustment'::character varying, 'reversal'::character varying]::text[])) AND amount <> 0::numeric", name: "ledger_amount_sign"
    t.check_constraint "kind::text = ANY (ARRAY['deposit'::character varying, 'withdrawal'::character varying, 'adjustment'::character varying, 'reversal'::character varying]::text[])", name: "ledger_kind"
  end

  create_table "candle_fingerprints", force: :cascade do |t|
    t.bigint "provider_request_id", null: false
    t.string "symbol", null: false
    t.string "interval", null: false
    t.datetime "opened_at", null: false
    t.string "digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["provider_request_id"], name: "index_candle_fingerprints_on_provider_request_id"
    t.index ["symbol", "interval", "opened_at"], name: "index_candle_fingerprints_on_symbol_and_interval_and_opened_at", unique: true
    t.check_constraint "\"interval\"::text = ANY (ARRAY['1h'::character varying, '4h'::character varying]::text[])", name: "candle_fingerprint_interval"
    t.check_constraint "digest::text ~ '^[0-9a-f]{64}$'::text", name: "candle_fingerprint_digest"
  end

  create_table "candles", force: :cascade do |t|
    t.bigint "provider_request_id", null: false
    t.string "symbol", null: false
    t.string "interval", null: false
    t.datetime "opened_at", null: false
    t.decimal "open", precision: 16, scale: 8, null: false
    t.decimal "high", precision: 16, scale: 8, null: false
    t.decimal "low", precision: 16, scale: 8, null: false
    t.decimal "close", precision: 16, scale: 8, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["provider_request_id"], name: "index_candles_on_provider_request_id"
    t.index ["symbol", "interval", "opened_at"], name: "index_candles_on_symbol_and_interval_and_opened_at", unique: true
    t.check_constraint "\"interval\"::text = ANY (ARRAY['1h'::character varying, '4h'::character varying]::text[])", name: "candle_interval"
    t.check_constraint "low > 0::numeric AND low <= LEAST(open, close) AND high >= GREATEST(open, close)", name: "candle_ohlc_consistent"
  end

  create_table "currency_pairs", force: :cascade do |t|
    t.string "symbol", null: false
    t.boolean "enabled", default: true, null: false
    t.integer "position", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["symbol"], name: "index_currency_pairs_on_symbol", unique: true
  end

  create_table "data_quality_metrics", force: :cascade do |t|
    t.bigint "provider_request_id", null: false
    t.datetime "evaluated_at", null: false
    t.string "status", null: false
    t.datetime "latest_closed_at"
    t.datetime "earliest_opened_at"
    t.integer "closed_count", null: false
    t.integer "incomplete_count", null: false
    t.integer "duplicate_count", null: false
    t.integer "gap_count", null: false
    t.integer "freshness_seconds"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "reproduced_count", default: 0, null: false
    t.integer "mismatch_count", default: 0, null: false
    t.integer "closure_count", default: 0, null: false
    t.integer "invalid_count", default: 0, null: false
    t.index ["provider_request_id"], name: "index_data_quality_metrics_on_provider_request_id", unique: true
    t.check_constraint "closed_count >= 0 AND incomplete_count >= 0 AND duplicate_count >= 0 AND gap_count >= 0", name: "quality_counts_nonnegative"
    t.check_constraint "closure_count >= 0", name: "quality_closure_nonnegative"
    t.check_constraint "invalid_count >= 0", name: "quality_invalid_nonnegative"
    t.check_constraint "reproduced_count >= 0 AND mismatch_count >= 0", name: "quality_reproduction_nonnegative"
  end

  create_table "provider_requests", force: :cascade do |t|
    t.string "symbol", null: false
    t.string "interval"
    t.string "endpoint", null: false
    t.datetime "requested_at", null: false
    t.string "status", null: false
    t.integer "http_status"
    t.integer "credits_used"
    t.integer "credits_left"
    t.string "error_code"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["requested_at"], name: "index_provider_requests_on_requested_at"
    t.check_constraint "(endpoint::text = ANY (ARRAY['time_series'::character varying, 'time_series_history'::character varying, 'earliest_timestamp'::character varying]::text[])) AND (\"interval\"::text = ANY (ARRAY['1h'::character varying, '4h'::character varying]::text[])) AND \"interval\" IS NOT NULL OR endpoint::text = 'forex_pairs'::text AND \"interval\" IS NULL", name: "provider_endpoint_interval"
    t.check_constraint "credits_left IS NULL OR credits_left >= 0", name: "provider_credits_left_nonnegative"
    t.check_constraint "credits_used IS NULL OR credits_used >= 0", name: "provider_credits_nonnegative"
  end

  create_table "risk_profiles", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "mode", default: "percentage", null: false
    t.decimal "risk_percent", precision: 5, scale: 2, default: "1.0", null: false
    t.decimal "fixed_risk", precision: 12, scale: 2
    t.decimal "reward_ratio", precision: 5, scale: 2, default: "2.0", null: false
    t.decimal "max_loss", precision: 12, scale: 2
    t.decimal "min_lot", precision: 8, scale: 2, default: "0.01", null: false
    t.decimal "lot_step", precision: 8, scale: 2, default: "0.01", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "stop_pips", precision: 7, scale: 1, default: "40.0", null: false
    t.index ["user_id"], name: "index_risk_profiles_on_user_id", unique: true
    t.check_constraint "max_loss IS NULL OR max_loss > 0::numeric", name: "risk_max_loss_positive"
    t.check_constraint "min_lot > 0::numeric AND lot_step > 0::numeric", name: "risk_lot_positive"
    t.check_constraint "mode::text <> 'fixed'::text OR fixed_risk > 0::numeric", name: "risk_fixed_present"
    t.check_constraint "mode::text = ANY (ARRAY['percentage'::character varying, 'fixed'::character varying]::text[])", name: "risk_mode"
    t.check_constraint "reward_ratio > 0::numeric", name: "risk_reward_positive"
    t.check_constraint "risk_percent > 0::numeric AND risk_percent <= 10::numeric", name: "risk_percent_range"
    t.check_constraint "stop_pips > 0::numeric AND stop_pips <= 1000::numeric", name: "risk_stop_pips_range"
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "last_active_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "strategies", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "name", null: false
    t.string "kind", null: false
    t.boolean "enabled", default: true, null: false
    t.datetime "archived_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "name"], name: "index_strategies_on_user_id_and_name", unique: true
    t.index ["user_id"], name: "index_strategies_on_user_id"
    t.check_constraint "kind::text = 'trend_pullback'::text", name: "strategy_kind"
  end

  create_table "strategy_runs", force: :cascade do |t|
    t.bigint "strategy_version_id", null: false
    t.string "symbol", null: false
    t.datetime "candle_opened_at", null: false
    t.string "verdict", null: false
    t.jsonb "explanation", default: {}, null: false
    t.datetime "evaluated_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["strategy_version_id", "symbol", "candle_opened_at"], name: "index_strategy_runs_once_per_candle", unique: true
    t.index ["strategy_version_id"], name: "index_strategy_runs_on_strategy_version_id"
    t.check_constraint "verdict::text = ANY (ARRAY['buy'::character varying, 'sell'::character varying, 'wait'::character varying]::text[])", name: "strategy_run_verdict"
  end

  create_table "strategy_versions", force: :cascade do |t|
    t.bigint "strategy_id", null: false
    t.integer "number", null: false
    t.jsonb "config", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["strategy_id", "number"], name: "index_strategy_versions_on_strategy_id_and_number", unique: true
    t.index ["strategy_id"], name: "index_strategy_versions_on_strategy_id"
  end

  create_table "trade_signals", force: :cascade do |t|
    t.bigint "strategy_version_id", null: false
    t.bigint "strategy_run_id", null: false
    t.string "symbol", null: false
    t.string "direction", null: false
    t.string "status", default: "active", null: false
    t.datetime "source_opened_at", null: false
    t.decimal "entry", precision: 16, scale: 8, null: false
    t.decimal "stop", precision: 16, scale: 8, null: false
    t.decimal "target", precision: 16, scale: 8, null: false
    t.decimal "entry_tolerance", precision: 16, scale: 8, null: false
    t.decimal "reward_ratio", precision: 5, scale: 2, null: false
    t.decimal "stop_pips", precision: 8, scale: 1, null: false
    t.decimal "planned_risk", precision: 12, scale: 2
    t.decimal "lots", precision: 8, scale: 2
    t.decimal "risk_at_size", precision: 12, scale: 2
    t.string "sizing_error"
    t.jsonb "evidence", default: {}, null: false
    t.datetime "generated_at", null: false
    t.datetime "expires_at", null: false
    t.string "status_reason"
    t.datetime "status_changed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["status"], name: "index_trade_signals_on_status"
    t.index ["strategy_run_id"], name: "index_trade_signals_on_strategy_run_id", unique: true
    t.index ["strategy_version_id", "symbol", "source_opened_at"], name: "index_trade_signals_once_per_candle", unique: true
    t.index ["strategy_version_id"], name: "index_trade_signals_on_strategy_version_id"
    t.check_constraint "direction::text = 'buy'::text AND stop < entry AND target > entry OR direction::text = 'sell'::text AND stop > entry AND target < entry", name: "signal_levels_direction"
    t.check_constraint "direction::text = ANY (ARRAY['buy'::character varying, 'sell'::character varying]::text[])", name: "signal_direction"
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying, 'invalidated'::character varying, 'expired'::character varying, 'completed'::character varying]::text[])", name: "signal_status"
  end

  create_table "trading_accounts", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "currency", default: "NZD", null: false
    t.decimal "starting_capital", precision: 14, scale: 2, null: false
    t.datetime "started_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_trading_accounts_on_user_id", unique: true
    t.check_constraint "currency::text = 'NZD'::text", name: "trading_account_currency_nzd"
    t.check_constraint "starting_capital >= 0::numeric", name: "trading_account_capital_nonnegative"
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "(true)", name: "index_users_single_owner", unique: true
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "account_ledger_entries", "account_ledger_entries", column: "reverses_entry_id"
  add_foreign_key "account_ledger_entries", "trading_accounts"
  add_foreign_key "candle_fingerprints", "provider_requests"
  add_foreign_key "candles", "provider_requests"
  add_foreign_key "data_quality_metrics", "provider_requests"
  add_foreign_key "risk_profiles", "users"
  add_foreign_key "sessions", "users"
  add_foreign_key "strategies", "users"
  add_foreign_key "strategy_runs", "strategy_versions"
  add_foreign_key "strategy_versions", "strategies"
  add_foreign_key "trade_signals", "strategy_runs"
  add_foreign_key "trade_signals", "strategy_versions"
  add_foreign_key "trading_accounts", "users"
end
