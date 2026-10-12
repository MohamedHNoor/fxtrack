require "csv"

# A trade decision the owner recorded by hand: taken (with actual fills) or
# skipped. Closing a taken trade realizes NZD P&L, which is posted to the
# account ledger. Signals never create these records.
class JournalTrade < ApplicationRecord
  STATUSES = %w[taken skipped].freeze
  DIRECTIONS = %w[buy sell].freeze
  UNITS_PER_LOT = 100_000
  CLOSING_FIELDS = %i[exit_price closed_at closing_rate].freeze
  # Exclusive upper bounds that fit decimal(16,8) prices and decimal(14,2) amounts.
  PRICE_LIMIT = 100_000_000
  AMOUNT_LIMIT = 1_000_000_000_000
  # Bookkeeping columns that never belong in an audit trail.
  UNAUDITED = %w[id trading_account_id created_at updated_at].freeze

  belongs_to :trading_account
  belongs_to :trade_signal, optional: true
  has_many :ledger_entries, class_name: "AccountLedgerEntry", dependent: :restrict_with_exception
  has_many :audit_events, -> { order(:created_at, :id) }, as: :auditable, dependent: :restrict_with_exception

  # A decision and its signal link are fixed; record a new entry instead.
  attr_readonly :status, :trade_signal_id

  before_validation :calculate_pnl

  validates :symbol, inclusion: { in: ProviderRequest::SYMBOLS }
  validates :direction, inclusion: { in: DIRECTIONS }
  validates :status, inclusion: { in: STATUSES }
  validates :trade_signal_id, uniqueness: { message: "already has a journal record" }, allow_nil: true
  validates :fees_nzd, numericality: { greater_than_or_equal_to: 0, less_than: AMOUNT_LIMIT }
  validates :financing_nzd, numericality: { greater_than: -AMOUNT_LIMIT, less_than: AMOUNT_LIMIT }
  validates :entry_price, :exit_price, :closing_rate, numericality: { less_than: PRICE_LIMIT }, allow_nil: true
  validates :units, numericality: { less_than: AMOUNT_LIMIT }, allow_nil: true
  validates :override_pnl_nzd, numericality: { greater_than: -AMOUNT_LIMIT, less_than: AMOUNT_LIMIT }, allow_nil: true
  validate :calculated_pnl_fits
  validates :notes, length: { maximum: 1000 }
  validates :override_reason, length: { maximum: 500 }

  with_options if: :taken? do
    validates :opened_at, :entry_price, :units, presence: true
    validates :entry_price, :units, numericality: { greater_than: 0 }, allow_nil: true
    validates :skipped_at, absence: true
  end

  with_options if: :skipped? do
    validates :skipped_at, presence: true
    validates :opened_at, :entry_price, :units, *CLOSING_FIELDS, :override_pnl_nzd, absence: { message: "must be blank for a skipped trade" }
    validates :fees_nzd, :financing_nzd, numericality: { equal_to: 0, message: "must be zero for a skipped trade" }
  end

  validate :closing_fields_complete
  validate :times_in_order
  validate :override_explained
  validate :matches_signal
  validate :correction_explained

  scope :newest_first, -> { order(Arel.sql("COALESCE(journal_trades.opened_at, journal_trades.skipped_at) DESC"), id: :desc) }

  CSV_HEADERS = %w[id state pair direction signal_id strategy opened_at closed_at skipped_at entry_price exit_price units lots
                   fees_nzd financing_nzd closing_rate_quote_per_nzd calculated_pnl_nzd override_pnl_nzd realized_pnl_nzd
                   pnl_source override_reason notes corrections updated_at].freeze

  # Spreadsheets run cells starting with these characters as formulas.
  def self.csv_text(value)
    value.to_s.match?(/\A[=+\-@\t\r]/) ? "'#{value}" : value
  end

  def self.to_csv(trades, time_zone:)
    zone = Time.find_zone!(time_zone)
    time = ->(value) { value&.in_time_zone(zone)&.iso8601 }
    number = ->(value) { value&.to_d&.to_s("F") }
    CSV.generate do |csv|
      csv << CSV_HEADERS
      trades.each do |trade|
        csv << [ trade.id, trade.state, trade.symbol, trade.direction, trade.trade_signal_id,
                 csv_text(trade.trade_signal&.strategy_version&.strategy&.name),
                 time.(trade.opened_at), time.(trade.closed_at), time.(trade.skipped_at),
                 number.(trade.entry_price), number.(trade.exit_price), number.(trade.units), number.(trade.lots),
                 number.(trade.fees_nzd), number.(trade.financing_nzd), number.(trade.closing_rate),
                 number.(trade.calculated_pnl_nzd), number.(trade.override_pnl_nzd), number.(trade.realized_pnl_nzd),
                 trade.pnl_source, csv_text(trade.override_reason), csv_text(trade.notes), trade.corrections_count, time.(trade.updated_at) ]
      end
    end
  end

  # Quote-currency P&L converted at a quote-per-NZD rate, net of NZD costs,
  # rounded once to cents.
  def self.calculate_pnl(direction:, entry:, exit:, units:, rate:, fees:, financing:)
    quote_pnl = (exit - entry) * units * (direction == "buy" ? 1 : -1)
    (quote_pnl / rate - fees + financing).round(2, BigDecimal::ROUND_HALF_UP)
  end

  def taken? = status == "taken"
  def skipped? = status == "skipped"
  def closed? = closed_at.present?

  def state
    return "skipped" if skipped?
    closed? ? "closed" : "open"
  end

  def realized_pnl_nzd
    override_pnl_nzd || calculated_pnl_nzd if closed?
  end

  def pnl_source
    return "none" unless closed?
    override_pnl_nzd ? "override" : "calculated"
  end

  def lots
    units / UNITS_PER_LOT if units
  end

  def recorded_at
    opened_at || skipped_at
  end

  # Counts in memory when the history is preloaded (CSV export), otherwise in SQL.
  def corrections_count
    return audit_events.to_a.count { |event| event.action == "corrected" } if audit_events.loaded?
    audit_events.where(action: "corrected").count
  end

  # The only write path. Saves the trade, records who changed what, and keeps
  # exactly one unreversed ledger posting equal to the realized P&L, all in one
  # transaction. Changing a trade that was already closed needs a reason.
  def record!(attributes, actor:, reason: nil)
    transaction do
      lock! if persisted?
      creating = new_record?
      @correcting = closed_at_in_database.present?
      @correction_reason = reason.to_s.strip.presence
      assign_attributes(attributes)
      save!

      changes = saved_changes.except(*UNAUDITED)
      if changes.any?
        action = creating ? "created" : (@correcting ? "corrected" : "updated")
        audit_events.create!(user: actor, action: action, changes_made: changes, reason: @correction_reason)
        sync_ledger_posting!
      end
    end
    self
  ensure
    @correcting = false
  end

  private
    def calculate_pnl
      inputs = [ entry_price, units, exit_price, closing_rate, fees_nzd, financing_nzd ]
      self.calculated_pnl_nzd =
        if taken? && closed_at && inputs.all? { |value| value.is_a?(Numeric) } && closing_rate.positive?
          self.class.calculate_pnl(direction: direction, entry: entry_price, exit: exit_price, units: units,
            rate: closing_rate, fees: fees_nzd, financing: financing_nzd)
        end
    end

    def calculated_pnl_fits
      errors.add(:base, "The calculated P&L is too large to record; check the prices, units and closing rate") if calculated_pnl_nzd && calculated_pnl_nzd.abs >= AMOUNT_LIMIT
    end

    def closing_fields_complete
      return unless taken?
      present = CLOSING_FIELDS.select { |field| self[field].present? }
      return if present.empty?

      (CLOSING_FIELDS - present).each { |field| errors.add(field, "is required to close the trade") }
      errors.add(:exit_price, "must be greater than 0") if exit_price && exit_price <= 0
      errors.add(:closing_rate, "must be greater than 0") if closing_rate && closing_rate <= 0
    end

    def times_in_order
      now = Time.current
      { opened_at: opened_at, closed_at: closed_at, skipped_at: skipped_at }.each do |field, time|
        errors.add(field, "cannot be in the future") if time && time > now
      end
      errors.add(:closed_at, "must be at or after the open time") if opened_at && closed_at && closed_at < opened_at
    end

    def override_explained
      if override_pnl_nzd.present?
        errors.add(:override_pnl_nzd, "needs a closed trade") unless closed?
        errors.add(:override_reason, "is required for a manual P&L override") if override_reason.blank?
      elsif override_reason.present?
        errors.add(:override_reason, "must be blank without a manual P&L override")
      end
    end

    def matches_signal
      return unless trade_signal
      errors.add(:trade_signal, "belongs to another owner") if trade_signal.strategy_version.strategy.user_id != trading_account&.user_id
      errors.add(:symbol, "must match the signal (#{trade_signal.symbol})") if symbol != trade_signal.symbol
      errors.add(:direction, "must match the signal (#{trade_signal.direction})") if direction != trade_signal.direction
    end

    def correction_explained
      return unless @correcting && changed?
      if @correction_reason.nil?
        errors.add(:base, "A correction reason is required to change a closed trade")
      elsif @correction_reason.length > 500
        errors.add(:base, "Correction reason is too long (maximum is 500 characters)")
      end
    end

    # Reversals keep the original posting's date so each period's ledger total
    # still matches the journal after a correction.
    def sync_ledger_posting!
      current = ledger_entries.where(kind: "trade").where.missing(:reversal).first
      amount = realized_pnl_nzd
      return if current && current.amount == amount && current.effective_at == closed_at

      current&.reverse!(notes: "Correction of #{symbol} #{direction} trade ##{id}", at: current.effective_at)
      return if amount.nil? || amount.zero?

      trading_account.ledger_entries.create!(kind: "trade", amount: amount, effective_at: closed_at, journal_trade: self,
        notes: "#{symbol} #{direction} closed (journal ##{id})")
    end
end
