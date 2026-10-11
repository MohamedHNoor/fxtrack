module SignalsHelper
  CONFIG_LABELS = {
    "ema_fast" => [ "Fast EMA (candles)", "Trend filter on H4 and H1" ],
    "ema_slow" => [ "Slow EMA (candles)", "Fast above slow is bullish" ],
    "atr_period" => [ "ATR period (H1 candles)", "Volatility used for zones, buffers and tolerance" ],
    "swing_strength" => [ "Swing strength (candles each side)", "Candles needed on both sides to confirm a swing" ],
    "swing_lookback" => [ "Swing lookback (H1 candles)", "How far back to look for support and resistance" ],
    "zone_atr" => [ "Zone width (x ATR)", "Support/resistance zone around the swing level" ],
    "pullback_candles" => [ "Pullback window (H1 candles)", "Recent candles that must touch the zone" ],
    "stop_buffer_atr" => [ "Stop buffer (x ATR)", "Distance beyond the swing for the stop" ],
    "min_stop_pips" => [ "Minimum stop (pips)", "Stops closer than this are widened" ],
    "spread_pips" => [ "Assumed spread (pips)", "Added to the stop distance when sizing" ],
    "entry_tolerance_atr" => [ "Entry tolerance (x ATR)", "Signal is invalidated if price moves further" ],
    "expiry_minutes" => [ "Expiry (minutes after candle close)", "Signals stop being actionable after this" ]
  }.freeze

  def direction_badge(direction)
    tone = direction == "buy" ? "bg-positive-bg text-positive" : (direction == "sell" ? "bg-negative-bg text-negative" : "bg-raised text-muted")
    tag.span(direction.upcase, class: "inline-flex rounded-lg px-2 py-1 text-xs font-bold #{tone}")
  end

  # Two or more live signals leaning the same way on USD compound one exposure
  # (for example buying NZD/USD and AUD/USD both sell USD).
  def usd_exposure_warnings(signals)
    signals.group_by(&:usd_exposure).filter_map do |exposure, group|
      next if group.size < 2
      "#{group.sort_by(&:symbol).map { |signal| "#{signal.direction} #{signal.symbol}" }.to_sentence} all #{exposure == :long_usd ? "buy" : "sell"} US dollars. Together they risk about #{nzd(group.sum { _1.risk_at_size || 0 })}, not one trade's risk."
    end
  end
end
