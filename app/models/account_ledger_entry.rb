# Immutable cash movements, realized trade P&L and corrections. Mistakes are
# fixed by recording a reversal of the original entry, never by editing or
# deleting it. Trade postings belong to a journal trade and are corrected only
# through the journal.
class AccountLedgerEntry < ApplicationRecord
  KINDS = %w[deposit withdrawal adjustment reversal trade].freeze

  belongs_to :trading_account
  belongs_to :journal_trade, optional: true
  belongs_to :reverses_entry, class_name: "AccountLedgerEntry", optional: true
  has_one :reversal, class_name: "AccountLedgerEntry", foreign_key: :reverses_entry_id, inverse_of: :reverses_entry

  validates :kind, inclusion: { in: KINDS }
  validates :amount, numericality: { other_than: 0 }
  validates :amount, numericality: { greater_than: 0 }, if: -> { kind == "deposit" }
  validates :amount, numericality: { less_than: 0 }, if: -> { kind == "withdrawal" }
  validates :effective_at, presence: true
  validates :notes, length: { maximum: 500 }
  validates :reverses_entry, presence: true, if: -> { kind == "reversal" }
  validates :reverses_entry_id, absence: true, unless: -> { kind == "reversal" }
  validates :reverses_entry_id, uniqueness: true, allow_nil: true
  validates :journal_trade, presence: true, if: -> { kind == "trade" }
  validates :journal_trade_id, absence: true, if: -> { %w[deposit withdrawal adjustment].include?(kind) }
  validate :reversal_matches_original, if: -> { kind == "reversal" && reverses_entry }
  validate :withdrawal_within_balance, on: :create, if: -> { kind == "withdrawal" }
  before_validation :lock_account_for_creation, on: :create

  before_destroy { raise ActiveRecord::ReadOnlyRecord, "Ledger entries are immutable" }

  def readonly?
    persisted? || super
  end

  def trade_pnl?
    journal_trade_id.present?
  end

  # Whether the owner can reverse this entry from the account page.
  def reversible?
    kind != "reversal" && !trade_pnl? && reversal.nil?
  end

  def reverse!(notes: nil, at: Time.current)
    trading_account.ledger_entries.create!(kind: "reversal", amount: -amount, reverses_entry: self, effective_at: at,
      journal_trade_id: journal_trade_id, notes: notes.presence || "Reverses #{kind} of #{created_at.to_date}")
  end

  private
    # save wraps validation and insertion in a transaction. Locking the shared
    # account serializes balance checks across concurrent requests.
    def lock_account_for_creation
      TradingAccount.where(id: trading_account_id).lock.pick(:id) if trading_account_id
    end

    def reversal_matches_original
      errors.add(:reverses_entry, "is already a reversal") if reverses_entry.kind == "reversal"
      errors.add(:reverses_entry, "belongs to another account") if reverses_entry.trading_account_id != trading_account_id
      errors.add(:amount, "must exactly offset the original entry") unless amount == -reverses_entry.amount
      errors.add(:journal_trade, "must match the original entry") unless journal_trade_id == reverses_entry.journal_trade_id
    end

    def withdrawal_within_balance
      return unless trading_account && amount
      errors.add(:amount, "exceeds the current balance") if trading_account.balance + amount < 0
    end
end
