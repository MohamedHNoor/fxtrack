module TwelveData
  class Probe
    MINUTE_BUDGET = 7
    DAY_BUDGET = 720
    LOCK_ID = 84_120_008

    def initialize(client: Client.new, clock: -> { Time.current }, sleeper: ->(seconds) { sleep seconds })
      @client, @clock, @sleeper = client, clock, sleeper
    end

    def run(symbol:, interval:)
      raise ArgumentError, "Unsupported forex symbol" unless ProviderRequest::SYMBOLS.include?(symbol)
      raise ArgumentError, "Unsupported interval" unless ProviderRequest::INTERVALS.include?(interval)
      3.times do |attempt|
        request = reserve(symbol, interval)
        return "quota_paused" unless request
        response = @client.time_series(symbol: symbol, interval: interval)
        persist(request, response, symbol, interval)
        return request.status unless retryable?(response) && attempt < 2
        delay = response.retry_after || 2**(attempt + 1)
        return request.status if delay > 60
        @sleeper.call(delay)
      end
    end

    private

    def reserve(symbol, interval)
      ProviderRequest.transaction do
        ProviderRequest.connection.execute("SELECT pg_advisory_xact_lock(#{LOCK_ID})")
        now = @clock.call.utc
        minute = Time.at((now.to_i / 60) * 60).utc
        day = now.beginning_of_day
        today = ProviderRequest.where(requested_at: day...day + 1.day)
        recent = today.where(requested_at: minute...minute + 60)
        next if used(today) >= DAY_BUDGET || used(recent) >= MINUTE_BUDGET
        last = recent.where.not(credits_left: nil).order(:requested_at, :id).last
        next if last && last.credits_left <= 1
        ProviderRequest.create!(symbol: symbol, interval: interval, endpoint: "time_series", requested_at: now, status: "reserved")
      end
    end

    def used(scope)
      scope.sum("GREATEST(COALESCE(credits_used, 1), 1)")
    end

    def persist(request, response, symbol, interval)
      ProviderRequest.transaction do
        request.update!(status: response.status, http_status: response.http_status,
          credits_used: response.credits_used, credits_left: response.credits_left, error_code: response.error_code)
        if response.status == "success"
          quality = Quality.new(clock: @clock).evaluate(response.payload, symbol: symbol, interval: interval)
          request.create_data_quality_metric!(quality)
          request.update!(status: "invalid_data", error_code: "invalid_response") unless quality[:status] == "valid"
        end
      end
    end

    def retryable?(response)
      %w[timeout transport_error rate_limited].include?(response.error_code) || response.http_status.to_i >= 500
    end
  end
end
