class ProviderRequest < ApplicationRecord
  SYMBOLS = %w[EUR/USD GBP/USD USD/JPY USD/CHF USD/CAD AUD/USD NZD/USD].freeze
  INTERVALS = %w[1h 4h].freeze
  # time_series_history is a full-size time_series window kept apart from collection.
  CANDLE_ENDPOINTS = %w[time_series time_series_history earliest_timestamp].freeze
  STATUSES = %w[reserved success provider_failure invalid_data].freeze
  ERROR_CODES = %w[timeout transport_error http_error rate_limited provider_error invalid_response].freeze

  has_one :data_quality_metric
  validates :symbol, inclusion: { in: SYMBOLS }
  validates :interval, inclusion: { in: INTERVALS }, if: -> { CANDLE_ENDPOINTS.include?(endpoint) }
  validates :interval, absence: true, if: -> { endpoint == "forex_pairs" }
  validates :endpoint, inclusion: { in: CANDLE_ENDPOINTS + %w[forex_pairs] }
  validates :status, inclusion: { in: STATUSES }
  validates :requested_at, presence: true
  validates :http_status, numericality: { only_integer: true, in: 100..599 }, allow_nil: true
  validates :credits_used, :credits_left, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :error_code, inclusion: { in: ERROR_CODES }, allow_nil: true
end
