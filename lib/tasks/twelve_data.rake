namespace :twelve_data do
  desc "Validate one catalogue symbol: twelve_data:catalogue[EUR/USD]"
  task :catalogue, [ :symbol ] => :environment do |_, args|
    abort "Provide a supported symbol" unless args[:symbol]
    status = TwelveData::Probe.new.run(symbol: args[:symbol], endpoint: "forex_pairs")
    puts({ symbol: args[:symbol], endpoint: "forex_pairs", status: status }.to_json)
    abort "Catalogue validation failed" unless status == "success"
  end

  desc "Collect one due cycle across seven pairs/H1/H4 within quota"
  task collect: :environment do
    result = TwelveData::Collection.new.run
    puts result.to_json
    abort "Collection had failures; consult sanitized metrics" if result[:status] == "partial_failure"
  end

  desc "Run one collection cycle per minute until interrupted (started by bin/dev)"
  task watch: :environment do
    $stdout.sync = true
    puts "twelve_data:watch started; stop with Ctrl-C"
    last_status = nil
    loop do
      begin
        result = MarketDataCollectionJob.perform_now
        puts({ at: Time.current.utc.iso8601, **result }.to_json) if result[:results].any? || result[:status] != last_status
        last_status = result[:status]
      rescue StandardError => error
        # Foreman stops bin/dev when a process exits, so log and keep observing.
        puts({ at: Time.current.utc.iso8601, status: "error", error: error.class.name }.to_json)
      end
      sleep 60 - Time.current.sec
    end
  rescue Interrupt
    puts "twelve_data:watch stopped"
  end

  desc "Measure historical depth unless measured within N hours (default 24): twelve_data:history[1]"
  task :history, [ :hours ] => :environment do |_, args|
    hours = Integer(args[:hours] || 24)
    abort "Hours must be between 1 and 24" unless (1..24).cover?(hours)
    ProviderRequest::SYMBOLS.product(ProviderRequest::INTERVALS).each do |symbol, interval|
      %w[earliest_timestamp time_series_history].each do |endpoint|
        # Invalid data is a final answer for the window; only provider failures retry.
        recent = ProviderRequest.where(symbol: symbol, interval: interval, endpoint: endpoint)
          .where(requested_at: hours.hours.ago..)
        stored = endpoint != "time_series_history" || Candle.where(symbol: symbol, interval: interval).exists?
        done = recent.where(status: "invalid_data").exists? || (stored && recent.where(status: "success").exists?)
        next if done
        status = TwelveData::Probe.new.run(symbol: symbol, interval: interval, endpoint: endpoint)
        puts({ symbol: symbol, interval: interval, endpoint: endpoint, status: status }.to_json)
        abort "Quota paused; rerun next minute to continue" if status == "quota_paused"
      end
    end
  end

  desc "Run one bounded diagnostic probe: twelve_data:probe[EUR/USD,1h]"
  task :probe, [ :symbol, :interval ] => :environment do |_, args|
    abort "Provide a supported symbol and interval (1h or 4h)" unless args[:symbol] && args[:interval]
    result = TwelveData::Probe.new.run(symbol: args[:symbol], interval: args[:interval])
    puts({ symbol: args[:symbol], interval: args[:interval], status: result }.to_json)
    abort "Probe did not succeed; consult sanitized metrics" unless result == "success"
  end

  desc "Summarize M00 acceptance evidence against the amended gate"
  task acceptance: :environment do
    result = TwelveData::Acceptance.new.call
    puts "M00 gate: #{result[:gate].upcase} (generated #{result[:generated_at].iso8601})"
    result[:checks].each { |name, item| puts format("  [%s] %-20s %s", item[:pass] ? "x" : " ", name, item[:detail]) }
    result[:combos].each { |row| puts row.to_json }
  end

  desc "Delete every stored candle (retention decision: within 30 days of cancelling)"
  task delete_candles: :environment do
    abort "Set CONFIRM=yes to delete all stored candles" unless ENV["CONFIRM"] == "yes"
    puts "Deleted #{Candle.delete_all} candles"
  end

  desc "Report diagnostic coverage without credentials or price data"
  task report: :environment do
    ProviderRequest::SYMBOLS.product(ProviderRequest::INTERVALS).each do |symbol, interval|
      requests = ProviderRequest.where(symbol: symbol, interval: interval, endpoint: "time_series")
      quality = DataQualityMetric.joins(:provider_request).where(provider_requests: { symbol: symbol, interval: interval, endpoint: "time_series" }).order(:evaluated_at, :id).last
      puts({ symbol: symbol, interval: interval, attempts: requests.count,
        reserved_credits: requests.count, latest_minute_credits_used: requests.order(:requested_at, :id).last&.credits_used, unknown_credit_header_attempts: requests.where(credits_used: nil).count,
        first_request_at: requests.minimum(:requested_at), last_request_at: requests.maximum(:requested_at),
        quality: quality&.attributes&.slice("status", "latest_closed_at", "freshness_seconds", "gap_count", "duplicate_count", "closure_count", "invalid_count", "reproduced_count", "mismatch_count") }.to_json)
    end
    ProviderRequest::SYMBOLS.product(ProviderRequest::INTERVALS).each do |symbol, interval|
      latest = ->(endpoint) { DataQualityMetric.joins(:provider_request).where(provider_requests: { symbol: symbol, interval: interval, endpoint: endpoint }).order(:evaluated_at, :id).last }
      earliest, window = latest.call("earliest_timestamp"), latest.call("time_series_history")
      span = window&.latest_closed_at && window.earliest_opened_at && ((window.latest_closed_at - window.earliest_opened_at) / 1.day).round(1)
      puts({ symbol: symbol, interval: interval, provider_earliest_timestamp: earliest&.earliest_opened_at,
        history_window: window&.attributes&.slice("status", "earliest_opened_at", "latest_closed_at", "closed_count", "closure_count", "invalid_count", "gap_count", "duplicate_count")&.merge("span_days" => span) }.to_json)
    end
    acceptance = TwelveData::Acceptance.new.call
    puts({ gate: acceptance[:gate], historical_retention: acceptance[:checks][:retention][:detail],
      closure_policy: "new_york_17_convention" }.to_json)
  end
end
