module TwelveData
  class Collection
    LOCK_ID = 84_120_009

    def initialize(probe: Probe.new, clock: -> { Time.current })
      @probe, @clock = probe, clock
    end

    def run
      ProviderRequest.connection_pool.with_connection do |connection|
        acquired = connection.select_value("SELECT pg_try_advisory_lock(#{LOCK_ID})")
        return { status: "already_running", results: [] } unless acquired
        begin
          collect
        ensure
          connection.execute("SELECT pg_advisory_unlock(#{LOCK_ID})")
        end
      end
    end

    private

    def collect
      candidates = ProviderRequest::SYMBOLS.product(ProviderRequest::INTERVALS)
      candidates.sort_by! { |symbol, interval| latest_request(symbol, interval)&.requested_at || Time.at(0).utc }
      results = []
      candidates.each do |symbol, interval|
        next unless due?(symbol, interval)
        status = @probe.run(symbol: symbol, interval: interval)
        results << { symbol: symbol, interval: interval, status: status }
        break if status == "quota_paused"
      end
      { status: results.any? { |item| !%w[success quota_paused].include?(item[:status]) } ? "partial_failure" : "collected", results: results }
    end

    def latest_request(symbol, interval)
      ProviderRequest.where(symbol: symbol, interval: interval, endpoint: "time_series").order(:requested_at, :id).last
    end

    def due?(symbol, interval)
      request = latest_request(symbol, interval)
      return true unless request
      now = @clock.call.utc
      return false if now < request.requested_at + 60
      metric = request.data_quality_metric
      return true unless request.status == "success" && metric
      duration = Quality::DURATIONS.fetch(interval)
      # A weekend-only response has no trading close; resume after the next
      # trading candle that should exist since the request.
      known = metric.latest_closed_at || MarketHours.last_expected_open(request.requested_at, duration) + duration
      now >= MarketHours.next_open(known, duration) + duration + 60
    end
  end
end
