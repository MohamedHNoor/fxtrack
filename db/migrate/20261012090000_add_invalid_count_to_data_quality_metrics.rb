class AddInvalidCountToDataQualityMetrics < ActiveRecord::Migration[8.1]
  def change
    add_column :data_quality_metrics, :invalid_count, :integer, null: false, default: 0
    add_check_constraint :data_quality_metrics, "invalid_count >= 0", name: "quality_invalid_nonnegative"
  end
end
