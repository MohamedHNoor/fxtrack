require "bigdecimal"
require "time"

module TwelveData
  class Quality
    DURATIONS = { "1h" => 3600, "4h" => 14_400 }.freeze

    def initialize(clock: -> { Time.current }, fingerprint_key: nil, max_values: 8)
      @clock, @max_values = clock, max_values
      @fingerprint_key = fingerprint_key || Rails.application.key_generator.generate_key("twelve_data candle fingerprint")
    end

    def evaluate(payload, symbol:, interval:)
      duration = DURATIONS.fetch(interval)
      now = @clock.call.utc
      attributes = { evaluated_at: now, status: "invalid", closed_count: 0, closure_count: 0, invalid_count: 0, incomplete_count: 0, duplicate_count: 0, gap_count: 0 }
      meta = payload["meta"]
      return attributes unless meta.is_a?(Hash) && meta["symbol"] == symbol && meta["interval"] == interval && meta["type"] == "Physical Currency"
      values = payload["values"]
      return attributes unless values.is_a?(Array) && values.size <= @max_values
      return attributes.merge(status: "empty") if values.empty?

      # Owner policy: drop and count candles that fail validation; their slots
      # surface as gaps. Window-level contradictions still reject everything.
      bars = values.filter_map { |value| parse_bar(value) }
      attributes[:invalid_count] = values.size - bars.size
      return attributes if bars.empty? || bars.any? { |bar| bar[:opened_at] > now }
      times = bars.map { |bar| bar[:opened_at] }
      return attributes unless times == times.sort
      grouped = bars.group_by { |bar| bar[:opened_at] }
      return attributes if grouped.values.any? { |copies| copies.uniq.size > 1 }
      unique = grouped.values.map(&:first)
      completed = unique.select { |bar| bar[:opened_at] + duration <= now }
      closure, trading = completed.partition { |bar| MarketHours.closed?(bar[:opened_at]) }
      attributes[:duplicate_count] = bars.size - unique.size
      attributes[:incomplete_count] = unique.size - completed.size
      attributes[:closed_count] = trading.size
      attributes[:closure_count] = closure.size
      attributes[:earliest_opened_at] = trading.first&.fetch(:opened_at)
      # Weekend candles are reported but never become reproducibility references.
      attributes[:fingerprints] = trading.to_h { |bar| [ bar[:opened_at], fingerprint(bar) ] }
      attributes[:candles] = trading.map { |bar| { opened_at: bar[:opened_at], **%i[open high low close].zip(bar[:prices]).to_h } }
      expected = MarketHours.last_expected_open(now, duration)
      if trading.empty?
        return attributes.merge(status: "empty") if closure.empty?
        # The window holds only weekend candles; it is current when it starts after
        # the last trading candle that should exist.
        return attributes.merge(status: closure.first[:opened_at] > expected ? "closed" : "stale")
      end

      latest = trading.last[:opened_at] + duration
      gaps = trading.each_cons(2).sum { |a, b| MarketHours.missing_opens(a[:opened_at], b[:opened_at], duration) }
      freshness = (now - latest).to_i
      status = if gaps.positive? then "gaps"
      elsif trading.last[:opened_at] < expected then "stale"
      elsif MarketHours.closed?(now) then "closed"
      else "valid"
      end
      attributes.merge(status: status, latest_closed_at: latest, freshness_seconds: freshness, gap_count: gaps)
    end

    private

    # BigDecimal#to_s("F") normalizes trailing zeros so equal prices match.
    def fingerprint(bar)
      canonical = [ bar[:opened_at].iso8601, *bar[:prices].map { |price| price.to_s("F") } ].join("|")
      OpenSSL::HMAC.hexdigest("SHA256", @fingerprint_key, canonical)
    end

    def parse_bar(value)
      return unless value.is_a?(Hash)
      stamp = value["datetime"]
      return unless stamp.is_a?(String) && stamp.match?(/\A\d{4}-\d\d-\d\d \d\d:\d\d:\d\d\z/)
      opened_at = Time.strptime("#{stamp} +0000", "%Y-%m-%d %H:%M:%S %z").utc
      return unless opened_at.strftime("%Y-%m-%d %H:%M:%S") == stamp
      prices = %w[open high low close].map do |field|
        text = value[field]
        return unless text.is_a?(String) && text.match?(/\A\d{1,12}(?:\.\d{1,11})?\z/)
        BigDecimal(text)
      end
      open, high, low, close = prices
      return unless prices.all?(&:positive?) && low <= [ open, close ].min && high >= [ open, close ].max && low <= high
      { opened_at: opened_at, prices: prices }
    rescue ArgumentError
      nil
    end
  end
end
