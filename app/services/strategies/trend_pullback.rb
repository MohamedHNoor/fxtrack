module Strategies
  # Trend Pullback Confirmation (project plan, strategy contract): completed H4
  # and H1 EMA alignment, a pullback into confirmed swing support/resistance and
  # an H1 engulfing confirmation, with a buffered stop and enough room to target.
  class TrendPullback
    Verdict = Data.define(:direction, :reasons, :entry, :stop, :target, :tolerance, :evidence) do
      def trade? = !direction.nil?
    end

    def initialize(config:, reward_ratio:, pip_size:)
      @c, @reward, @pip = config, BigDecimal(reward_ratio.to_s), pip_size
    end

    def evaluate(h4:, h1:)
      minimum_h1 = [ @c["ema_slow"], @c["swing_lookback"], @c["atr_period"] + 1 ].max + 1
      return wait("Not enough completed candles yet (need #{@c["ema_slow"] + 1} H4 and #{minimum_h1} H1)") if h4.size <= @c["ema_slow"] || h1.size < minimum_h1

      h4_trend, h4_emas = trend(h4)
      h1_trend, h1_emas = trend(h1)
      evidence = { "h4_trend" => h4_trend, "h4_ema_fast" => h4_emas[0], "h4_ema_slow" => h4_emas[1],
                   "h1_trend" => h1_trend, "h1_ema_fast" => h1_emas[0], "h1_ema_slow" => h1_emas[1] }
      return wait("H4 trend is #{h4_trend} but H1 trend is #{h1_trend}", evidence) unless h4_trend == h1_trend && h4_trend != "flat"

      atr = Indicators.atr(h1, @c["atr_period"])
      evidence["atr"] = atr
      h4_trend == "bullish" ? setup(h1, atr, evidence, "buy") : setup(h1, atr, evidence, "sell")
    end

    private
      def trend(candles)
        closes = candles.map(&:close)
        fast, slow = Indicators.ema(closes, @c["ema_fast"]).last, Indicators.ema(closes, @c["ema_slow"]).last
        [ fast > slow ? "bullish" : (fast < slow ? "bearish" : "flat"), [ fast.round(6), slow.round(6) ] ]
      end

      def setup(h1, atr, evidence, direction)
        buy = direction == "buy"
        window = h1.last(@c["swing_lookback"])
        last, previous = h1.last, h1[-2]
        level_side, obstacle_side = buy ? [ :low, :high ] : [ :high, :low ]
        levels = Indicators.swings(window, @c["swing_strength"], level_side).map { |index| window[index] }
        swing = levels.reverse.find { |candle| buy ? candle.low < last.close : candle.high > last.close }
        name = buy ? "support" : "resistance"
        return wait("No confirmed swing #{name} #{buy ? "below" : "above"} price in the last #{@c["swing_lookback"]} H1 candles", evidence) unless swing

        level = buy ? swing.low : swing.high
        zone = atr * BigDecimal(@c["zone_atr"].to_s)
        evidence.merge!("swing_level" => level, "swing_at" => swing.opened_at.iso8601, "zone_low" => level - zone, "zone_high" => level + zone)
        touched = h1.last(@c["pullback_candles"]).find { |candle| buy ? candle.low <= level + zone : candle.high >= level - zone }
        return wait("Price has not pulled back to #{name} at #{level.round(5).to_s("F")} in the last #{@c["pullback_candles"]} H1 candles", evidence) unless touched
        return wait("Price closed beyond the #{name} zone", evidence) if buy ? last.close < level - zone : last.close > level + zone

        evidence["pullback_at"] = touched.opened_at.iso8601
        engulfing = buy ? Indicators.bullish_engulfing?(previous, last) : Indicators.bearish_engulfing?(previous, last)
        return wait("No #{buy ? "bullish" : "bearish"} engulfing confirmation on the latest H1 candle", evidence) unless engulfing
        evidence["confirmation_at"] = last.opened_at.iso8601

        entry = last.close
        buffer = atr * BigDecimal(@c["stop_buffer_atr"].to_s)
        stop = buy ? level - buffer : level + buffer
        minimum = BigDecimal(@c["min_stop_pips"].to_s) * @pip
        if (entry - stop).abs < minimum
          stop = buy ? entry - minimum : entry + minimum
          evidence["stop_widened_to_minimum"] = true
        end
        risk = (entry - stop).abs
        target = buy ? entry + risk * @reward : entry - risk * @reward

        obstacles = Indicators.swings(window, @c["swing_strength"], obstacle_side).map { |index| window[index] }
        obstacle = obstacles.reverse.map { |candle| buy ? candle.high : candle.low }.find { |price| buy ? price > entry : price < entry }
        if obstacle
          evidence["next_obstacle"] = obstacle
          if (obstacle - entry).abs < risk * @reward
            return wait("Next #{buy ? "resistance" : "support"} at #{obstacle.round(5).to_s("F")} leaves less than #{@reward.to_s("F")}R of room", evidence)
          end
        end

        reasons = [ "H4 and H1 trends are #{evidence["h4_trend"]}", "Pullback to #{name} at #{level.round(5).to_s("F")}",
                    "#{buy ? "Bullish" : "Bearish"} engulfing on the latest H1 candle" ]
        Verdict.new(direction: direction, reasons: reasons, entry: entry, stop: stop, target: target,
          tolerance: atr * BigDecimal(@c["entry_tolerance_atr"].to_s), evidence: evidence)
      end

      def wait(reason, evidence = {})
        Verdict.new(direction: nil, reasons: [ reason ], entry: nil, stop: nil, target: nil, tolerance: nil, evidence: evidence)
      end
  end
end
