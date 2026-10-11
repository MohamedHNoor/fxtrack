# Accepted closed trading candles. Stored only for internal owner use under the
# 2026-10-11 retention decision; `twelve_data:delete_candles` removes them all.
class Candle < ApplicationRecord
  belongs_to :provider_request

  validates :symbol, inclusion: { in: ProviderRequest::SYMBOLS }
  validates :interval, inclusion: { in: ProviderRequest::INTERVALS }
  validates :opened_at, presence: true, uniqueness: { scope: [ :symbol, :interval ] }
  validates :open, :high, :low, :close, numericality: { greater_than: 0 }

  scope :series, ->(symbol, interval) { where(symbol: symbol, interval: interval).order(:opened_at) }

  def closed_at
    opened_at + TwelveData::Quality::DURATIONS.fetch(interval)
  end
end
