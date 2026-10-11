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
      raise ArgumentError, "Unsupported endpoint" unless ProviderRequest::CANDLE_ENDPOINTS.include?(endpoint) || endpoint == "forex_pairs"
      raise ArgumentError, "Unsupported interval" if endpoint != "forex_pairs" && !ProviderRequest::INTERVALS.include?(interval)
      raise ArgumentError, "Catalogue has no interval" if endpoint == "forex_pairs" && interval
      3.times do |attempt|
        request = reserve(symbol, interval, endpoint)
        return "quota_paused" unless request
        response = case endpoint
        when "time_series" then @client.time_series(symbol: symbol, interval: interval)
        when "time_series_history" then @client.time_series(symbol: symbol, interval: interval, outputsize: Client::HISTORY_SIZE)
        when "earliest_timestamp" then @client.earliest_timestamp(symbol: symbol, interval: interval)
        else @client.forex_pairs(symbol: symbol)
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
        elsif response.status == "success" && request.endpoint == "earliest_timestamp"
          record_earliest(request, response.payload)
        elsif response.status == "success"
          history = request.endpoint == "time_series_history"
          quality = Quality.new(clock: @clock, max_values: history ? Client::HISTORY_SIZE : 8)
            .evaluate(response.payload, symbol: symbol, interval: interval)
          previous = latest_trading_close(symbol, interval)
          if previous && quality[:latest_closed_at] && quality[:latest_closed_at] < previous
            quality[:status] = "invalid"
          end
          fingerprints = quality.delete(:fingerprints) || {}
          candles = quality.delete(:candles) || []
          reproduce(request, fingerprints, quality) unless quality[:status] == "invalid"
          store_candles(request, candles) unless %w[invalid unreproducible].include?(quality[:status])
          request.create_data_quality_metric!(quality)
          # Long windows span holidays, so gaps are measured evidence, not a failed request.
          accepted = history ? %w[valid closed gaps] : %w[valid closed]
          request.update!(status: "invalid_data", error_code: "invalid_response") unless accepted.include?(quality[:status])
        end
      end
    end

    # Metrics recorded before the closure rule can end on a weekend candle; only a
    # trading close is a valid reference for detecting timestamp regression.
    def latest_trading_close(symbol, interval)
      duration = Quality::DURATIONS.fetch(interval)
      DataQualityMetric.joins(:provider_request)
        .where(provider_requests: { symbol: symbol, interval: interval, endpoint: "time_series" })
        .where.not(latest_closed_at: nil).order(latest_closed_at: :desc).limit(MarketHours::MAX_STEPS)
        .pluck(:latest_closed_at).find { |closed_at| !MarketHours.closed?(closed_at - duration) }
    end

    # Candles reaching here passed validation and the fingerprint check, so an
    # existing row for the same open time already holds identical prices.
    def store_candles(request, candles)
      return if candles.empty?
      rows = candles.map { |candle| candle.merge(provider_request_id: request.id, symbol: request.symbol, interval: request.interval) }
      Candle.insert_all(rows, unique_by: %i[symbol interval opened_at])
    end

    def record_earliest(request, payload)
      unix = payload["unix_time"]
      now = @clock.call.utc
      unless unix.is_a?(Integer) && unix.positive? && unix <= now.to_i
        return request.update!(status: "invalid_data", error_code: "invalid_response")
      end
      request.create_data_quality_metric!(status: "valid", evaluated_at: now, earliest_opened_at: Time.at(unix).utc,
        closed_count: 0, incomplete_count: 0, duplicate_count: 0, gap_count: 0)
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
