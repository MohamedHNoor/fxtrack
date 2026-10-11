module Strategies
  # Deterministic indicators over completed candles (oldest first), in BigDecimal.
  module Indicators
    module_function

    # Exponential moving average seeded with the simple average of the first period.
    def ema(values, period)
      return [] if values.size < period
      k = BigDecimal(2) / (period + 1)
      seed = values.first(period).sum / period
      values.drop(period).each_with_object([ seed ]) { |value, out| out << (value - out.last) * k + out.last }
    end

    # Wilder's average true range; nil until enough candles exist.
    def atr(candles, period)
      return if candles.size <= period
      ranges = candles.each_cons(2).map do |previous, current|
        [ current.high - current.low, (current.high - previous.close).abs, (current.low - previous.close).abs ].max
      end
      ranges.drop(period).reduce(ranges.first(period).sum / period) { |average, range| (average * (period - 1) + range) / period }
    end

    # Indexes of confirmed swing lows (or highs): strictly beyond every candle
    # `strength` positions either side. The last `strength` candles cannot be
    # confirmed yet, which avoids lookahead.
    def swings(candles, strength, side)
      (strength...(candles.size - strength)).select do |index|
        value = side == :low ? candles[index].low : candles[index].high
        neighbours = candles[(index - strength)..(index + strength)].each_with_index.reject { |_, offset| offset == strength }.map(&:first)
        side == :low ? neighbours.all? { |candle| value < candle.low } : neighbours.all? { |candle| value > candle.high }
      end
    end

    def bullish_engulfing?(previous, current)
      previous.close < previous.open && current.close > current.open && current.open <= previous.close && current.close >= previous.open
    end

    def bearish_engulfing?(previous, current)
      previous.close > previous.open && current.close < current.open && current.open >= previous.close && current.close <= previous.open
    end
  end
end
