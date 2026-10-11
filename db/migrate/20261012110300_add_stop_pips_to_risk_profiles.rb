class AddStopPipsToRiskProfiles < ActiveRecord::Migration[8.1]
  def change
    add_column :risk_profiles, :stop_pips, :decimal, precision: 7, scale: 1, null: false, default: 40
    add_check_constraint :risk_profiles, "stop_pips > 0 AND stop_pips <= 1000", name: "risk_stop_pips_range"
  end
end
