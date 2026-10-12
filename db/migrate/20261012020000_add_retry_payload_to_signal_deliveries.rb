class AddRetryPayloadToSignalDeliveries < ActiveRecord::Migration[8.1]
  def change
    add_column :signal_deliveries, :email_payload, :jsonb
    add_column :signal_deliveries, :first_attempted_at, :datetime
  end
end
