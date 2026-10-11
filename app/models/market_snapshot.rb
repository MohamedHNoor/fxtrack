# Read model for one pair and interval: latest stored candle and data status.
class MarketSnapshot
  attr_reader :symbol, :interval, :latest, :previous, :last_request

  def self.for(symbol, interval, now: Time.current)
    latest, previous = Candle.series(symbol, interval).reorder(opened_at: :desc).limit(2).to_a
    last_request = ProviderRequest.where(symbol: symbol, interval: interval, endpoint: "time_series").order(:requested_at, :id).last
    new(symbol, interval, latest, previous, last_request, now)
  end

  def initialize(symbol, interval, latest, previous, last_request, now)
    @symbol, @interval, @latest, @previous, @last_request, @now = symbol, interval, latest, previous, last_request, now
  end

  def duration
    TwelveData::Quality::DURATIONS.fetch(interval)
  end

  def change
    latest.close - previous.close if latest && previous
  end

  def change_percent
    (change / previous.close * 100).round(2) if change
  end

  # Priority: missing data, then a failing provider, then the weekend rule,
  # then freshness against the last trading candle that should have closed.
  def state
    return :no_data unless latest
    return :provider_failure if last_request&.status == "provider_failure"
    return :market_closed if TwelveData::MarketHours.closed?(@now)
    expected_open = TwelveData::MarketHours.last_expected_open(@now, duration)
    latest.opened_at >= expected_open ? :fresh : :stale
  end

  def label
    { no_data: "No data yet", provider_failure: "Provider failing", market_closed: "Market closed", fresh: "Fresh", stale: "Stale" }.fetch(state)
  end
end
