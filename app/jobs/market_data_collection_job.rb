# Monitoring runs only while at least one valid owner session exists
# (project plan: closing a browser does not stop it; expiry or logout does).
class MarketDataCollectionJob < ApplicationJob
  queue_as :default

  def perform
    return { status: "no_active_session", results: [] } unless Session.active.exists?
    symbols = Rails.configuration.x.collect_all_pairs ? ProviderRequest::SYMBOLS : CurrencyPair.enabled.ordered.pluck(:symbol)
    return { status: "no_enabled_pairs", results: [] } if symbols.empty?

    result = TwelveData::Collection.new(symbols: symbols).run
    # Analysis runs after every cycle on enabled pairs; it skips candles it has already evaluated.
    signals = Strategies::SignalEngine.new.run
    signals[:signals].positive? ? result.merge(signals: signals) : result
  end
end
