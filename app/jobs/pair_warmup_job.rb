# Fetches a history window for a newly enabled pair so indicators have enough
# candles. Signals still come only from fresh candles, so warm-up history can
# never produce a retroactive alert.
class PairWarmupJob < ApplicationJob
  queue_as :default
  MINIMUM_CANDLES = 300

  def perform(symbol)
    return unless User.first&.monitoring_active? && CurrencyPair.enabled.exists?(symbol: symbol)
    ProviderRequest::INTERVALS.each do |interval|
      next if Candle.where(symbol: symbol, interval: interval).count >= MINIMUM_CANDLES
      TwelveData::Probe.new.run(symbol: symbol, interval: interval, endpoint: "time_series_history")
    end
  end
end
