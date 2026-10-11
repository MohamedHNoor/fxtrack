module MarketsHelper
  OWNER_TIME_ZONE = Rails.configuration.x.owner_time_zone

  def price_decimals(symbol)
    symbol.end_with?("JPY") ? 3 : 5
  end

  def format_price(symbol, value)
    value ? number_with_precision(value, precision: price_decimals(symbol)) : "No data"
  end

  def owner_time(time)
    time ? time.in_time_zone(OWNER_TIME_ZONE).strftime("%-d %b %Y, %H:%M %Z") : "None"
  end

  def change_class(change)
    return "text-muted" if change.nil? || change.zero?
    change.positive? ? "text-positive" : "text-negative"
  end

  def state_badge(snapshot)
    tones = { fresh: "border-positive/50 text-positive", market_closed: "border-line text-muted", stale: "border-warning/60 text-warning",
              provider_failure: "border-negative/60 text-negative", no_data: "border-line text-faint" }
    tag.span(snapshot.label, class: "inline-flex rounded-lg border px-2 py-1 text-xs font-semibold whitespace-nowrap #{tones.fetch(snapshot.state)}")
  end

  # Lightweight Charts plots UTC timestamps; shifting by the owner offset shows
  # New Zealand wall-clock times, including daylight saving changes.
  def chart_series(candles)
    candles.map do |candle|
      { time: candle.opened_at.to_i + candle.opened_at.in_time_zone(OWNER_TIME_ZONE).utc_offset,
        open: candle.open.to_f, high: candle.high.to_f, low: candle.low.to_f, close: candle.close.to_f }
    end
  end
end
