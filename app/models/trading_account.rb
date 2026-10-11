class TradingAccount < ApplicationRecord
  belongs_to :user
  has_many :ledger_entries, -> { order(:effective_at, :id) }, class_name: "AccountLedgerEntry", dependent: :restrict_with_exception

  validates :currency, inclusion: { in: %w[NZD] }
  validates :starting_capital, numericality: { greater_than_or_equal_to: 0 }
  validates :started_at, presence: true
  validates :user_id, uniqueness: true
  # Capital history must stay auditable: corrections are ledger adjustments.
  attr_readonly :starting_capital, :started_at

  # Balance = starting capital + deposits - withdrawals + adjustments (and
  # reversals). Realized trade P&L joins the ledger with the journal (M10).
  def balance
    starting_capital + ledger_entries.sum(:amount)
  end

  def totals
    sums = ledger_entries.reorder(nil).group(:kind).sum(:amount)
    { deposits: sums.fetch("deposit", 0), withdrawals: sums.fetch("withdrawal", 0),
      adjustments: sums.fetch("adjustment", 0) + sums.fetch("reversal", 0) }
  end
end
