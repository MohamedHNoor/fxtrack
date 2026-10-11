class CreateNotificationTables < ActiveRecord::Migration[8.1]
  def change
    create_table :notification_preferences do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.boolean :email_enabled, null: false, default: false
      t.boolean :notify_new_signal, null: false, default: true
      t.boolean :notify_expired, null: false, default: false
      t.boolean :notify_invalidated, null: false, default: false
      t.timestamps
    end

    create_table :signal_deliveries do |t|
      t.references :trade_signal, null: false, foreign_key: true
      t.string :channel, null: false
      t.string :event, null: false
      t.string :status, null: false, default: "pending"
      t.integer :attempts, null: false, default: 0
      t.datetime :sent_at
      t.string :error_code
      t.string :reason
      t.timestamps
    end
    # One delivery per signal, channel and event: retries can never double-send.
    add_index :signal_deliveries, [ :trade_signal_id, :channel, :event ], unique: true, name: "index_signal_deliveries_once"
    add_index :signal_deliveries, :status
    add_check_constraint :signal_deliveries, "channel IN ('email')", name: "signal_delivery_channel"
    add_check_constraint :signal_deliveries, "event IN ('new_signal', 'expired', 'invalidated')", name: "signal_delivery_event"
    add_check_constraint :signal_deliveries, "status IN ('pending', 'sent', 'failed', 'suppressed')", name: "signal_delivery_status"
  end
end
