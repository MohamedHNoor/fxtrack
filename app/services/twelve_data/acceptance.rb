module TwelveData
  # Summarizes M00 evidence against the owner-amended gate (docs, Acceptance window):
  # history windows, a fingerprint revision check, 48 cumulative live trading hours,
  # quota compliance and the recorded retention decision.
  class Acceptance
    LIVE_START = Time.utc(2026, 10, 11, 21)
    REQUIRED_LIVE_HOURS = 48

    def initialize(clock: -> { Time.current })
      @clock = clock
    end

    def call
      combos = ProviderRequest::SYMBOLS.product(ProviderRequest::INTERVALS).map { |symbol, interval| combo(symbol, interval) }
      hours = live_hours
      quota = quota_usage
      checks = {
        history_windows: check(combos.all? { |row| row[:history_measured] }, "every pair/interval has a valid history window"),
        revision_check: check(combos.all? { |row| row[:history_repeated] && row[:history_mismatches].zero? },
          "every history window was repeated with zero fingerprint mismatches"),
        live_hours: check(hours >= REQUIRED_LIVE_HOURS, "#{hours} of #{REQUIRED_LIVE_HOURS} cumulative live trading hours"),
        live_reproducibility: check(combos.all? { |row| row[:reproduced].positive? && row[:mismatches].zero? },
          "every pair/interval reproduced live closes with zero mismatches"),
        quota: check(quota[:max_per_minute] <= Probe::MINUTE_BUDGET && quota[:max_per_day] <= Probe::DAY_BUDGET,
          "peak #{quota[:max_per_minute]}/minute and #{quota[:max_per_day]}/day within #{Probe::MINUTE_BUDGET} and #{Probe::DAY_BUDGET}"),
        retention: check(true, "owner decision recorded 2026-10-11 (docs, Retention-rights review)")
      }
      { generated_at: @clock.call.utc, gate: checks.values.all? { |item| item[:pass] } ? "pass" : "pending",
        checks: checks, live_hours: hours, quota: quota, combos: combos }
    end

    private

    def check(pass, detail)
      { pass: pass, detail: detail }
    end

    def combo(symbol, interval)
      live = ProviderRequest.where(symbol: symbol, interval: interval, endpoint: "time_series", requested_at: LIVE_START..)
      live_metrics = DataQualityMetric.where(provider_request: live)
      history = DataQualityMetric.joins(:provider_request).where(provider_requests: { symbol: symbol, interval: interval,
        endpoint: "time_series_history", status: "success" })
      latest = live_metrics.order(:evaluated_at, :id).last
      {
        symbol: symbol, interval: interval,
        requests: live.count, outcomes: live.group(:status).count, errors: live.where.not(error_code: nil).group(:error_code).count,
        reproduced: live_metrics.sum(:reproduced_count), mismatches: live_metrics.sum(:mismatch_count),
        invalid_candles: live_metrics.sum(:invalid_count), latest_status: latest&.status, latest_freshness_seconds: latest&.freshness_seconds,
        history_measured: history.exists?, history_repeated: history.count >= 2, history_mismatches: history.sum(:mismatch_count)
      }
    end

    # Active collection is measured as distinct trading-hour buckets containing a
    # live request; bin/dev restarts leave operator gaps, not provider gaps.
    def live_hours
      ProviderRequest.where(endpoint: "time_series", requested_at: LIVE_START..@clock.call)
        .pluck(Arel.sql("DISTINCT date_trunc('hour', requested_at)"))
        .count { |hour| !MarketHours.closed?(hour.utc) }
    end

    def quota_usage
      scope = ProviderRequest.where(requested_at: LIVE_START..)
      per_minute = scope.group(Arel.sql("date_trunc('minute', requested_at)")).count.values.max.to_i
      per_day = scope.group(Arel.sql("date_trunc('day', requested_at)")).count.values.max.to_i
      { max_per_minute: per_minute, max_per_day: per_day, total: scope.count }
    end
  end
end
