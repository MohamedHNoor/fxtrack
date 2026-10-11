# Immutable rule configuration. Only supported, bounded parameters are stored;
# strategies never run user-supplied code (project plan, strategy contract).
class StrategyVersion < ApplicationRecord
  # Owner-approved Trend Pullback Confirmation V1 defaults (2026-10-11).
  DEFAULTS = {
    "ema_fast" => 20, "ema_slow" => 50, "atr_period" => 14,
    "swing_strength" => 3, "swing_lookback" => 50, "zone_atr" => 0.25,
    "pullback_candles" => 3, "stop_buffer_atr" => 0.5, "min_stop_pips" => 10,
    "spread_pips" => 1.5, "entry_tolerance_atr" => 0.25, "expiry_minutes" => 30
  }.freeze
  BOUNDS = {
    "ema_fast" => 2..200, "ema_slow" => 3..400, "atr_period" => 2..100,
    "swing_strength" => 1..10, "swing_lookback" => 10..200, "zone_atr" => 0.0..5.0,
    "pullback_candles" => 1..20, "stop_buffer_atr" => 0.0..5.0, "min_stop_pips" => 0.0..500.0,
    "spread_pips" => 0.0..50.0, "entry_tolerance_atr" => 0.0..5.0, "expiry_minutes" => 5..1440
  }.freeze
  INTEGER_KEYS = %w[ema_fast ema_slow atr_period swing_strength swing_lookback pullback_candles expiry_minutes].freeze

  belongs_to :strategy
  has_many :runs, class_name: "StrategyRun", dependent: :restrict_with_exception
  has_many :trade_signals, dependent: :restrict_with_exception

  before_validation :normalize_config
  validates :number, numericality: { only_integer: true, greater_than: 0 }, uniqueness: { scope: :strategy_id }
  validate :config_within_bounds

  before_destroy { raise ActiveRecord::ReadOnlyRecord, "Strategy versions are immutable" }

  def readonly?
    persisted? || super
  end

  def label
    "#{strategy.name} · version #{number}"
  end

  def setting(key)
    config.fetch(key)
  end

  private
    def normalize_config
      raw = (config || {}).to_h.stringify_keys.slice(*DEFAULTS.keys)
      self.config = DEFAULTS.merge(raw).to_h do |key, value|
        number = INTEGER_KEYS.include?(key) ? Integer(value.to_s, exception: false) : Float(value.to_s, exception: false)
        [ key, number.nil? ? value : number ]
      end
    end

    def config_within_bounds
      config.each do |key, value|
        errors.add(:config, "#{key.humanize} must be between #{BOUNDS[key].min} and #{BOUNDS[key].max}") unless value.is_a?(Numeric) && BOUNDS[key].cover?(value)
      end
      errors.add(:config, "Ema fast must be shorter than ema slow") if config["ema_fast"].is_a?(Numeric) && config["ema_slow"].is_a?(Numeric) && config["ema_fast"] >= config["ema_slow"]
    end
end
