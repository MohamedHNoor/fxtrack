class CurrencyPair < ApplicationRecord
  validates :symbol, inclusion: { in: ProviderRequest::SYMBOLS }, uniqueness: true
  validates :position, numericality: { only_integer: true }

  # Idempotent: creates any missing supported pair (enabled) without changing
  # existing rows, so owner choices survive reseeding.
  def self.ensure_seeded!
    rows = ProviderRequest::SYMBOLS.each_with_index.map { |symbol, index| { symbol: symbol, enabled: true, position: index } }
    insert_all(rows, unique_by: :symbol)
  end

  scope :ordered, -> { order(:position) }
  scope :enabled, -> { where(enabled: true) }

  # URL-safe identifier: "EUR/USD" becomes "EURUSD".
  def to_param
    symbol.delete("/")
  end

  def self.find_by_param!(param)
    code = param.to_s.upcase
    raise ActiveRecord::RecordNotFound, "Unknown currency pair" unless code.match?(/\A[A-Z]{6}\z/)
    find_by!(symbol: code.insert(3, "/"))
  end

  # A pip is the fourth decimal place, or the second for JPY-quoted pairs.
  def self.pip_size(symbol)
    symbol.end_with?("JPY") ? BigDecimal("0.01") : BigDecimal("0.0001")
  end

  def pip_size
    self.class.pip_size(symbol)
  end

  def base
    symbol.split("/").first
  end

  def quote
    symbol.split("/").last
  end
end
