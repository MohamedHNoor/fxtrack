require "bigdecimal"
require "time"

module TwelveData
  class Quality
    DURATIONS = { "1h" => 3600, "4h" => 14_400 }.freeze

    def initialize(clock: -> { Time.current })
      @clock = clock
    end

    def evaluate(payload, symbol:, interval:)
      duration = DURATIONS.fetch(interval)
      now = @clock.call.utc
      attributes = { evaluated_at: now, status: "invalid", closed_count: 0, incomplete_count: 0, duplicate_count: 0, gap_count: 0 }
      meta = payload["meta"]
      return attributes unless meta.is_a?(Hash) && meta["symbol"] == symbol && meta["interval"] == interval && meta["type"] == "Physical Currency"
      values = payload["values"]
      return attributes unless values.is_a?(Array) && values.size <= 8
      return attributes.merge(status: "empty") if values.empty?

      bars = values.map { |value| parse_bar(value) }
      return attributes if bars.any?(&:nil?) || bars.any? { |bar| bar[:opened_at] > now }
      times = bars.map { |bar| bar[:opened_at] }
      return attributes unless times == times.sort
      grouped = bars.group_by { |bar| bar[:opened_at] }
      return attributes if grouped.values.any? { |copies| copies.uniq.size > 1 }
      unique = grouped.values.map(&:first)
      closed = unique.select { |bar| bar[:opened_at] + duration <= now }
      attributes[:duplicate_count] = bars.size - unique.size
      attributes[:incomplete_count] = unique.size - closed.size
      attributes[:closed_count] = closed.size
      attributes[:earliest_opened_at] = closed.first&.fetch(:opened_at)
      return attributes.merge(status: "empty") if closed.empty?

      latest = closed.last[:opened_at] + duration
      gaps = closed.each_cons(2).sum { |a, b| [ ((b[:opened_at] - a[:opened_at]) / duration).ceil - 1, 0 ].max }
      freshness = (now - latest).to_i
      status = gaps.positive? ? "gaps" : (freshness >= duration ? "stale" : "valid")
      attributes.merge(status: status, latest_closed_at: latest, freshness_seconds: freshness, gap_count: gaps)
    end

    private

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
