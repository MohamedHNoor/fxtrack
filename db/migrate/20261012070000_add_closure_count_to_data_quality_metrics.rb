class AddClosureCountToDataQualityMetrics < ActiveRecord::Migration[8.1]
  def change
    add_column :data_quality_metrics, :closure_count, :integer, null: false, default: 0
    add_check_constraint :data_quality_metrics, "closure_count >= 0", name: "quality_closure_nonnegative"
  end
end
