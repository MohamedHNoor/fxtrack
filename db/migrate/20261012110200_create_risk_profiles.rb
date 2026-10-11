class CreateRiskProfiles < ActiveRecord::Migration[8.1]
  def change
    create_table :risk_profiles do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.string :mode, null: false, default: "percentage"
      t.decimal :risk_percent, precision: 5, scale: 2, null: false, default: 1.0
      t.decimal :fixed_risk, precision: 12, scale: 2
      t.decimal :reward_ratio, precision: 5, scale: 2, null: false, default: 2.0
      t.decimal :max_loss, precision: 12, scale: 2
      t.decimal :min_lot, precision: 8, scale: 2, null: false, default: 0.01
      t.decimal :lot_step, precision: 8, scale: 2, null: false, default: 0.01
      t.timestamps
    end
    add_check_constraint :risk_profiles, "mode IN ('percentage', 'fixed')", name: "risk_mode"
    add_check_constraint :risk_profiles, "risk_percent > 0 AND risk_percent <= 10", name: "risk_percent_range"
    add_check_constraint :risk_profiles, "mode <> 'fixed' OR fixed_risk > 0", name: "risk_fixed_present"
    add_check_constraint :risk_profiles, "reward_ratio > 0", name: "risk_reward_positive"
    add_check_constraint :risk_profiles, "max_loss IS NULL OR max_loss > 0", name: "risk_max_loss_positive"
    add_check_constraint :risk_profiles, "min_lot > 0 AND lot_step > 0", name: "risk_lot_positive"
  end
end
