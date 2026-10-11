# A proposed trade. Signals never create journal trades or move capital.
# Lifecycle: active -> expired (time), invalidated (price or setup broke) or
# completed (reserved for the journal in M10; nothing completes signals yet).
class TradeSignal < ApplicationRecord
  STATUSES = %w[active invalidated expired completed].freeze

  belongs_to :strategy_version
  belongs_to :strategy_run

  validates :symbol, inclusion: { in: ProviderRequest::SYMBOLS }
  validates :direction, inclusion: { in: %w[buy sell] }
  validates :status, inclusion: { in: STATUSES }
  validates :entry, :stop, :target, numericality: { greater_than: 0 }

  scope :active, -> { where(status: "active") }
  scope :recent, -> { order(generated_at: :desc) }

  def actionable?(now = Time.current)
    status == "active" && expires_at > now
  end

  def remaining_seconds(now = Time.current)
    [ (expires_at - now).to_i, 0 ].max
  end

  def close!(status, reason, at: Time.current)
    update!(status: status, status_reason: reason, status_changed_at: at)
  end

  # Buying a XXX/USD pair sells USD; buying USD/XXX buys USD.
  def usd_exposure
    base_is_usd = symbol.start_with?("USD/")
    (direction == "buy") == base_is_usd ? :long_usd : :short_usd
  end
end
