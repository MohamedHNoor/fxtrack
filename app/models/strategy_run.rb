class StrategyRun < ApplicationRecord
  belongs_to :strategy_version
  has_one :trade_signal, dependent: :restrict_with_exception

  validates :symbol, inclusion: { in: ProviderRequest::SYMBOLS }
  validates :verdict, inclusion: { in: %w[buy sell wait] }
  validates :candle_opened_at, :evaluated_at, presence: true

  def reasons
    explanation.fetch("reasons", [])
  end
end
