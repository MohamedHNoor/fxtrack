class AllowCatalogueRequestsWithoutInterval < ActiveRecord::Migration[8.1]
  def change
    change_column_null :provider_requests, :interval, true
    add_check_constraint :provider_requests,
      "(endpoint = 'time_series' AND interval IN ('1h', '4h') AND interval IS NOT NULL) OR (endpoint = 'forex_pairs' AND interval IS NULL)",
      name: "provider_endpoint_interval"
  end
end
