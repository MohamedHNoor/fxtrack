module TwelveData
  class Probe
    MINUTE_BUDGET = 7
    DAY_BUDGET = 720
    LOCK_ID = 84_120_008

    def initialize(client: Client.new, clock: -> { Time.current }, sleeper: ->(seconds) { sleep seconds })
      @client, @clock, @sleeper = client, clock, sleeper
    end

    def run(symbol:, interval: nil, endpoint: "time_series")
      raise ArgumentError, "Unsupported forex symbol" unless ProviderRequest::SYMBOLS.include?(symbol)
      raise ArgumentError, "Unsupported interval" if endpoint == "time_series" && !ProviderRequest::INTERVALS.include?(interval)
      raise ArgumentError, "Unsupported endpoint" unless %w[time_series forex_pairs].include?(endpoint)
      raise ArgumentError, "Catalogue has no interval" if endpoint == "forex_pairs" && interval
      3.times do |attempt|
        request = reserve(symbol, interval, endpoint)
        return "quota_paused" unless request
        response = if endpoint == "time_series"
          @client.time_series(symbol: symbol, interval: interval)
        else
          @client.forex_pairs(symbol: symbol)
        end
        persist(request, response, symbol, interval)
        return request.status unless retryable?(response) && attempt < 2
        delay = response.retry_after || 2**(attempt + 1)
        return request.status if delay > 60
        @sleeper.call(delay)
      end
    end

    private

    def reserve(symbol, interval, endpoint)
      ProviderRequest.transaction do
        ProviderRequest.connection.execute("SELECT pg_advisory_xact_lock(#{LOCK_ID})")
        now = @clock.call.utc
        minute = Time.at((now.to_i / 60) * 60).utc
        day = now.beginning_of_day
        today = ProviderRequest.where(requested_at: day...day + 1.day)
        recent = today.where(requested_at: minute...minute + 60)
        next if used(today) >= DAY_BUDGET || used(recent) >= MINUTE_BUDGET
        remaining = recent.minimum(:credits_left)
        remote_used = recent.maximum(:credits_used).to_i
        pending = recent.where(status: "reserved").count
        next if (remaining && remaining <= 1) || remote_used + pending >= MINUTE_BUDGET
        ProviderRequest.create!(symbol: symbol, interval: interval, endpoint: endpoint, requested_at: now, status: "reserved")
      end
    end

    def used(scope)
      scope.count
    end

    def persist(request, response, symbol, interval)
      ProviderRequest.transaction do
        request.update!(status: response.status, http_status: response.http_status,
          credits_used: response.credits_used, credits_left: response.credits_left, error_code: response.error_code)
        if response.status == "success" && request.endpoint == "forex_pairs"
          entries = response.payload["data"]
          listed = entries.is_a?(Array) && entries.any? { |entry| entry.is_a?(Hash) && entry["symbol"] == symbol }
          request.update!(status: "invalid_data", error_code: "invalid_response") unless listed
        elsif response.status == "success"
          quality = Quality.new(clock: @clock).evaluate(response.payload, symbol: symbol, interval: interval)
          previous = DataQualityMetric.joins(:provider_request)
            .where(provider_requests: { symbol: symbol, interval: interval, endpoint: "time_series" })
            .where.not(latest_closed_at: nil).maximum(:latest_closed_at)
          if previous && quality[:latest_closed_at] && quality[:latest_closed_at] < previous
            quality[:status] = "invalid"
          end
          fingerprints = quality.delete(:fingerprints) || {}
          reproduce(request, fingerprints, quality) unless quality[:status] == "invalid"
          request.create_data_quality_metric!(quality)
          request.update!(status: "invalid_data", error_code: "invalid_response") unless quality[:status] == "valid"
        end
      end
    end

    # Inserts first so concurrent probes compare against one stored digest; the
    # savepoint discards new digests from a response that contradicts known ones.
    def reproduce(request, fingerprints, quality)
      return if fingerprints.empty?
      digests = fingerprints.transform_keys(&:to_i)
      inserted = mismatches = 0
      CandleFingerprint.transaction(requires_new: true) do
        rows = fingerprints.map do |opened_at, digest|
          { provider_request_id: request.id, symbol: request.symbol, interval: request.interval, opened_at: opened_at, digest: digest }
        end
        inserted = CandleFingerprint.insert_all(rows, unique_by: %i[symbol interval opened_at], returning: %i[id]).length
        stored = CandleFingerprint.where(symbol: request.symbol, interval: request.interval, opened_at: fingerprints.keys).pluck(:opened_at, :digest)
        mismatches = stored.count { |opened_at, digest| digests[opened_at.to_i] != digest }
        raise ActiveRecord::Rollback if mismatches.positive?
      end
      quality[:mismatch_count] = mismatches
      quality[:reproduced_count] = fingerprints.size - inserted - mismatches
      quality[:status] = "unreproducible" if mismatches.positive?
    end

    def retryable?(response)
      %w[timeout transport_error rate_limited].include?(response.error_code) || response.http_status.to_i >= 500
    end
  end
end
