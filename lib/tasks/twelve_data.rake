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

  desc "Run one bounded diagnostic probe: twelve_data:probe[EUR/USD,1h]"
  task :probe, [ :symbol, :interval ] => :environment do |_, args|
    abort "Provide a supported symbol and interval (1h or 4h)" unless args[:symbol] && args[:interval]
    result = TwelveData::Probe.new.run(symbol: args[:symbol], interval: args[:interval])
    puts({ symbol: args[:symbol], interval: args[:interval], status: result }.to_json)
    abort "Probe did not succeed; consult sanitized metrics" unless result == "success"
  end

  desc "Report diagnostic coverage without credentials or price data"
  task report: :environment do
    ProviderRequest::SYMBOLS.product(ProviderRequest::INTERVALS).each do |symbol, interval|
      requests = ProviderRequest.where(symbol: symbol, interval: interval, endpoint: "time_series")
      quality = DataQualityMetric.joins(:provider_request).where(provider_requests: { symbol: symbol, interval: interval }).order(:evaluated_at, :id).last
      puts({ symbol: symbol, interval: interval, attempts: requests.count,
        reserved_credits: requests.count, latest_minute_credits_used: requests.order(:requested_at, :id).last&.credits_used, unknown_credit_header_attempts: requests.where(credits_used: nil).count,
        first_request_at: requests.minimum(:requested_at), last_request_at: requests.maximum(:requested_at),
        quality: quality&.attributes&.slice("status", "latest_closed_at", "freshness_seconds", "gap_count", "duplicate_count", "closure_count", "reproduced_count", "mismatch_count") }.to_json)
    end
    puts({ gate: "pending", historical_retention: "unresolved", closure_policy: "unverified" }.to_json)
  end
end
