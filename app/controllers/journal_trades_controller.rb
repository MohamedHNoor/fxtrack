class JournalTradesController < ApplicationController
  layout "app"
  before_action :set_account
  before_action :set_trade, only: %i[ show edit update ]

  TAKEN_FIELDS = %i[ symbol direction opened_at entry_price units exit_price closed_at closing_rate fees_nzd financing_nzd
                     override_pnl_nzd override_reason notes ].freeze
  SKIPPED_FIELDS = %i[ symbol direction skipped_at notes ].freeze
  TIME_FIELDS = %i[ opened_at closed_at skipped_at ].freeze

  STATES = %w[ open closed skipped ].freeze

  def index
    @strategies = Current.user.strategies.order(:name)
    @filters = journal_filters
    @trades = filtered(@account.journal_trades).newest_first.includes(trade_signal: { strategy_version: :strategy })
    @open_count = @account.journal_trades.where(status: "taken", closed_at: nil).count
    @closed_count = @account.journal_trades.where.not(closed_at: nil).count
    respond_to do |format|
      format.html
      format.csv do
        # Only the export needs audit history (for the corrections column).
        send_data JournalTrade.to_csv(@trades.includes(:audit_events), time_zone: Rails.configuration.x.owner_time_zone), type: :csv,
          filename: "fxtrack-journal-#{Time.current.in_time_zone(Rails.configuration.x.owner_time_zone).strftime("%Y%m%d")}.csv"
      end
    end
  end

  def show
  end

  def new
    @trade = @account.journal_trades.build(status: "taken", opened_at: Time.current)
    return unless params[:signal_id].present?

    signal = TradeSignal.owned_by(Current.user).find(params[:signal_id])
    return redirect_to(journal_trade_path(signal.journal_trade)) if signal.journal_trade
    @trade.assign_attributes(trade_signal: signal, symbol: signal.symbol, direction: signal.direction)
  end

  def create
    attrs = params.expect(journal_trade: [ :status, :trade_signal_id, *TAKEN_FIELDS, :skipped_at ])
    status = attrs[:status] == "skipped" ? "skipped" : "taken"
    signal = TradeSignal.owned_by(Current.user).find(attrs[:trade_signal_id]) if attrs[:trade_signal_id].present?
    @trade = @account.journal_trades.build
    save_trade(attrs, trade_attributes(attrs, status).merge(status: status, trade_signal: signal), :new, "#{status.capitalize} trade recorded.")
  end

  def edit
  end

  def update
    attrs = params.expect(journal_trade: [ *TAKEN_FIELDS, :skipped_at ])
    save_trade(attrs, trade_attributes(attrs, @trade.status), :edit, "Journal record updated.", reason: params[:correction_reason])
  end

  private
    def set_account
      @account = Current.user.trading_account or redirect_to(account_path, alert: "Set up the account first.")
    end

    def set_trade
      @trade = @account.journal_trades.find(params[:id])
    end

    # Keeps only recognised filter values, so invalid ones are dropped and the
    # form shows them cleared.
    def journal_filters
      {
        pair: params[:pair].presence_in(ProviderRequest::SYMBOLS),
        state: params[:state].presence_in(STATES),
        strategy: params[:strategy] == "manual" ? "manual" : @strategies.find { |strategy| strategy.id.to_s == params[:strategy] }&.id&.to_s,
        from: filter_date(params[:from]),
        to: filter_date(params[:to])
      }.compact
    end

    def filter_date(value)
      Date.iso8601(value.to_s).iso8601 if value.present?
    rescue Date::Error
      nil
    end

    # Dates are owner calendar days applied to when the trade was opened or skipped.
    def filtered(trades)
      zone = Time.find_zone!(Rails.configuration.x.owner_time_zone)
      recorded_at = Arel.sql("COALESCE(journal_trades.opened_at, journal_trades.skipped_at)")
      trades = trades.where(symbol: @filters[:pair]) if @filters[:pair]
      trades = case @filters[:state]
      when "open" then trades.where(status: "taken", closed_at: nil)
      when "closed" then trades.where.not(closed_at: nil)
      when "skipped" then trades.where(status: "skipped")
      else trades
      end
      if @filters[:strategy] == "manual"
        trades = trades.where(trade_signal_id: nil)
      elsif @filters[:strategy]
        trades = trades.joins(trade_signal: :strategy_version).where(strategy_versions: { strategy_id: @filters[:strategy] })
      end
      trades = trades.where(recorded_at.gteq(zone.parse(@filters[:from]).beginning_of_day)) if @filters[:from]
      trades = trades.where(recorded_at.lteq(zone.parse(@filters[:to]).end_of_day)) if @filters[:to]
      trades
    end

    # Only the fields that apply to the decision are taken; times are owner
    # wall-clock and blank costs mean zero.
    def trade_attributes(attrs, status)
      fields = status == "skipped" ? SKIPPED_FIELDS : TAKEN_FIELDS
      fields.index_with do |field|
        value = attrs[field]
        if TIME_FIELDS.include?(field) then parse_owner_time(value)
        elsif %i[fees_nzd financing_nzd].include?(field) then value.presence || "0"
        else value.presence
        end
      end
    end

    # Unparseable values (for example 2026-13-01T10:00) must not read as blank,
    # which would silently reopen a trade.
    def parse_owner_time(value)
      owner_time_param(value)
    rescue ArgumentError
      nil
    end

    def invalid_times(attrs)
      TIME_FIELDS.select { |field| attrs[field].present? && parse_owner_time(attrs[field]).nil? }
    end

    def save_trade(params_attrs, attributes, template, notice, reason: nil)
      if (invalid = invalid_times(params_attrs).select { |field| attributes.key?(field) }).any?
        @trade.assign_attributes(attributes.except(*invalid))
        invalid.each { |field| @trade.errors.add(field, "is not a valid date and time") }
        return render(template, status: :unprocessable_entity)
      end

      @trade.record!(attributes, actor: Current.user, reason: reason)
      redirect_to journal_trade_path(@trade), notice: notice
    rescue ActiveRecord::RecordInvalid => error
      raise unless error.record == @trade
      render template, status: :unprocessable_entity
    rescue ActiveRecord::RecordNotUnique
      raise unless attributes[:trade_signal].present?
      # Two concurrent submissions for the same signal raced past validation.
      @trade.errors.add(:trade_signal, "already has a journal record")
      render template, status: :unprocessable_entity
    end
end
