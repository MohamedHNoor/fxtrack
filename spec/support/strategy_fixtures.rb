# Deterministic candle series for strategy specs. `buy_setup` is an H1
# uptrend with a confirmed swing low at 1.1249, a pullback into its zone and a
# bullish engulfing close at 1.1290. `mirror` reflects prices to build sells.
module StrategyFixtures
  Bar = Data.define(:opened_at, :open, :high, :low, :close)

  def bar(time, open, close, wick: "0.0003")
    o, c, w = BigDecimal(open.to_s), BigDecimal(close.to_s), BigDecimal(wick)
    Bar.new(time, o, [ o, c ].max + w, [ o, c ].min - w, c)
  end

  def uptrend(count, start: Time.utc(2026, 9, 1), step_hours: 1)
    (0...count).map { |i| close = BigDecimal("1.1000") + BigDecimal("0.0005") * i; bar(start + (i * step_hours).hours, close - BigDecimal("0.0002"), close) }
  end

  def buy_setup(start: Time.utc(2026, 9, 1), resistance: false)
    h1 = uptrend(56, start: start)
    moves = [ [ "1.1275", "1.1262" ], [ "1.1262", "1.1252" ], [ "1.1256", "1.1266" ], [ "1.1266", "1.1280" ], [ "1.1280", "1.1294" ],
              [ "1.1294", "1.1306" ], [ resistance ? "1.1303" : "1.1306", "1.1300" ], [ "1.1300", "1.1282" ], [ "1.1282", "1.1256" ], [ "1.1255", "1.1290" ] ]
    moves.each_with_index { |(open, close), k| h1 << bar(start + (56 + k).hours, open, close) }
    { h4: uptrend(60, start: start - 240.hours, step_hours: 4), h1: h1 }
  end

  def mirror(series, around: "2.3")
    pivot = BigDecimal(around)
    series.transform_values do |bars|
      bars.map { |b| Bar.new(b.opened_at, pivot - b.open, pivot - b.low, pivot - b.high, pivot - b.close) }
    end
  end
end

RSpec.configure { |config| config.include StrategyFixtures }
