# M00 diagnostics and explicit unattended monitoring may outlive owner sessions.
class MarketDataCollectionJob < ApplicationJob
  queue_as :default

  def perform
    diagnostics = Rails.configuration.x.m00_diagnostics
    return { status: "no_active_session", results: [] } unless diagnostics || User.first&.monitoring_active?
    symbols = diagnostics || Rails.configuration.x.collect_all_pairs ? ProviderRequest::SYMBOLS : CurrencyPair.enabled.ordered.pluck(:symbol)
    return { status: "no_enabled_pairs", results: [] } if symbols.empty?

    result = TwelveData::Collection.new(symbols: symbols).run
    return result unless User.first&.monitoring_active?
    # Analysis runs after every cycle on enabled pairs; it skips candles it has already evaluated.
    signals = Strategies::SignalEngine.new.run
    signals[:signals].positive? ? result.merge(signals: signals) : result
  end
end
