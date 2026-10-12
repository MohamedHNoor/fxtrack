class TradingAccount < ApplicationRecord
  belongs_to :user
  has_many :ledger_entries, -> { order(:effective_at, :id) }, class_name: "AccountLedgerEntry", dependent: :restrict_with_exception
  has_many :journal_trades, dependent: :restrict_with_exception

  validates :currency, inclusion: { in: %w[NZD] }
  validates :starting_capital, numericality: { greater_than_or_equal_to: 0 }
  validates :started_at, presence: true
  validates :user_id, uniqueness: true
  # Capital history must stay auditable: corrections are ledger adjustments.
  attr_readonly :starting_capital, :started_at

  # Balance = starting capital + deposits - withdrawals + realized net
  # closed-trade P&L + adjustments (and reversals). Closed journal trades post
  # their P&L to the ledger; open trades are not included.
  def balance
    starting_capital + ledger_entries.sum(:amount)
  end

  # Reversals of trade postings count as trade P&L, other reversals as adjustments.
  def totals
    sums = ledger_entries.reorder(nil).group(:kind, Arel.sql("journal_trade_id IS NOT NULL")).sum(:amount)
    { deposits: sums.fetch([ "deposit", false ], 0), withdrawals: sums.fetch([ "withdrawal", false ], 0),
      closed_trade_pnl: sums.fetch([ "trade", true ], 0) + sums.fetch([ "reversal", true ], 0),
      adjustments: sums.fetch([ "adjustment", false ], 0) + sums.fetch([ "reversal", false ], 0) }
  end
end
