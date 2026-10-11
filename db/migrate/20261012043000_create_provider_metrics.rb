class CreateProviderMetrics < ActiveRecord::Migration[8.1]
  def change
    create_table :provider_requests do |t|
      t.string :symbol, null: false
      t.string :interval, null: false
      t.string :endpoint, null: false
      t.datetime :requested_at, null: false
      t.string :status, null: false
      t.integer :http_status
      t.integer :credits_used
      t.integer :credits_left
      t.string :error_code
      t.timestamps
    end
    add_index :provider_requests, :requested_at
    add_check_constraint :provider_requests, "credits_used IS NULL OR credits_used >= 0", name: "provider_credits_nonnegative"
    add_check_constraint :provider_requests, "credits_left IS NULL OR credits_left >= 0", name: "provider_credits_left_nonnegative"

    create_table :data_quality_metrics do |t|
      t.references :provider_request, null: false, foreign_key: true, index: { unique: true }
      t.datetime :evaluated_at, null: false
      t.string :status, null: false
      t.datetime :latest_closed_at
      t.datetime :earliest_opened_at
      t.integer :closed_count, null: false
      t.integer :incomplete_count, null: false
      t.integer :duplicate_count, null: false
      t.integer :gap_count, null: false
      t.integer :freshness_seconds
      t.timestamps
    end
    add_check_constraint :data_quality_metrics, "closed_count >= 0 AND incomplete_count >= 0 AND duplicate_count >= 0 AND gap_count >= 0", name: "quality_counts_nonnegative"
  end
end
