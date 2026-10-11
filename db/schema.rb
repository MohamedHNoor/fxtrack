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

ActiveRecord::Schema[8.1].define(version: 2026_10_12_043000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

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
    t.index ["provider_request_id"], name: "index_data_quality_metrics_on_provider_request_id", unique: true
    t.check_constraint "closed_count >= 0 AND incomplete_count >= 0 AND duplicate_count >= 0 AND gap_count >= 0", name: "quality_counts_nonnegative"
  end

  create_table "provider_requests", force: :cascade do |t|
    t.string "symbol", null: false
    t.string "interval", null: false
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
    t.check_constraint "credits_left IS NULL OR credits_left >= 0", name: "provider_credits_left_nonnegative"
    t.check_constraint "credits_used IS NULL OR credits_used >= 0", name: "provider_credits_nonnegative"
  end

  add_foreign_key "data_quality_metrics", "provider_requests"
end
