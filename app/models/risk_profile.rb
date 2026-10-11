class RiskProfile < ApplicationRecord
  MODES = %w[percentage fixed].freeze

  belongs_to :user

  validates :mode, inclusion: { in: MODES }
  validates :risk_percent, numericality: { greater_than: 0, less_than_or_equal_to: 10 }
  validates :fixed_risk, numericality: { greater_than: 0 }, if: -> { mode == "fixed" }
  validates :fixed_risk, numericality: { greater_than: 0 }, allow_nil: true
  validates :reward_ratio, numericality: { greater_than: 0, less_than_or_equal_to: 20 }
  validates :max_loss, numericality: { greater_than: 0 }, allow_nil: true
  validates :min_lot, :lot_step, numericality: { greater_than: 0 }
  validates :stop_pips, numericality: { greater_than: 0, less_than_or_equal_to: 1000 }

  # Unsaved defaults until the owner saves settings, so viewing never writes.
  def self.for(user)
    find_or_initialize_by(user: user)
  end

  # Planned loss in NZD before size rounding.
  def planned_risk(balance)
    raw = mode == "fixed" ? fixed_risk : (balance * risk_percent / 100).round(2)
    max_loss ? [ raw, max_loss ].min : raw
  end
end
