module TwelveData
  # Owner-selected convention: the FX week closes Friday 17:00 and reopens Sunday
  # 17:00 America/New_York. Twelve Data documents no forex session and returns
  # moving weekend candles, so this rule is ours, not provider-confirmed.
  module MarketHours
    ZONE = "America/New_York"
    # A weekend spans at most 48 H1 slots; the cap bounds walks over odd data.
    MAX_STEPS = 100

    module_function

    def closed?(time)
      local = time.in_time_zone(ZONE)
      (local.friday? && local.hour >= 17) || local.saturday? || (local.sunday? && local.hour < 17)
    end

    # Open time of the most recent trading candle that has closed by now.
    def last_expected_open(now, duration)
      open = Time.at(((now.to_i - duration) / duration) * duration).utc
      MAX_STEPS.times { closed?(open) ? open -= duration : break }
      open
    end

    # First trading candle open at or after the given grid-aligned time.
    def next_open(from, duration)
      open = from.utc
      MAX_STEPS.times { closed?(open) ? open += duration : break }
      open
    end

    # Trading candles missing strictly between two candle opens.
    def missing_opens(earlier, later, duration)
      slots = ((later - earlier) / duration).ceil - 1
      return [ slots, 0 ].max if slots > MAX_STEPS
      (1..slots).count { |step| !closed?(earlier + step * duration) }
    end
  end
end
