module JournalHelper
  PNL_SOURCES = { "calculated" => "Calculated", "override" => "Manual override", "none" => "Not realized" }.freeze
  STATE_TONES = { "open" => "border-info/50 text-info", "closed" => "border-line text-fg", "skipped" => "border-line text-faint" }.freeze

  def pnl_source_label(trade)
    PNL_SOURCES.fetch(trade.pnl_source)
  end

  def journal_state_badge(trade)
    tag.span(trade.state.capitalize, class: "inline-flex rounded-lg border px-2 py-1 text-xs font-semibold #{STATE_TONES.fetch(trade.state)}")
  end

  # NZD amount without the currency, for columns already labelled NZD.
  def signed_amount(amount)
    "#{"+" if amount.positive?}#{number_with_precision(amount, precision: 2, delimiter: ",")}"
  end

  def owner_date(time)
    time&.in_time_zone(MarketsHelper::OWNER_TIME_ZONE)&.to_date&.iso8601
  end

  # One-line status for history rows and cards.
  def journal_summary(trade)
    case trade.state
    when "closed" then "Closed #{owner_date(trade.closed_at)}"
    when "open" then "Open since #{owner_date(trade.opened_at)}"
    else "Skipped #{owner_date(trade.skipped_at)}"
    end
  end

  # Value for a datetime-local field, shown as owner wall-clock time.
  def owner_local_value(time)
    time&.in_time_zone(MarketsHelper::OWNER_TIME_ZONE)&.strftime("%Y-%m-%dT%H:%M")
  end

  # Audit values are stored as JSON strings; show times in owner time.
  def audit_value(field, value)
    return "blank" if value.nil?
    return owner_time(Time.zone.parse(value)) if JournalTrade.columns_hash[field]&.type == :datetime
    value
  end

  def money_value(value)
    format("%.2f", value) if value
  end

  def plain_decimal(value)
    value&.to_d&.to_s("F")
  end
end
