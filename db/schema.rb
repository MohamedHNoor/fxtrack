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

ActiveRecord::Schema[8.1].define(version: 2026_10_12_100100) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

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

  create_table "sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "last_active_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "(true)", name: "index_users_single_owner", unique: true
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "candle_fingerprints", "provider_requests"
  add_foreign_key "candles", "provider_requests"
  add_foreign_key "data_quality_metrics", "provider_requests"
  add_foreign_key "sessions", "users"
end
