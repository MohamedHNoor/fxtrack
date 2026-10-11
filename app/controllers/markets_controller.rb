class MarketsController < ApplicationController
  layout "app"
  CHART_CANDLES = 300

  def index
    @pairs = CurrencyPair.enabled.ordered
    @snapshots = @pairs.to_h { |pair| [ pair.symbol, ProviderRequest::INTERVALS.to_h { |interval| [ interval, MarketSnapshot.for(pair.symbol, interval) ] } ] }
  end

  def show
    @pair = CurrencyPair.find_by_param!(params[:id])
    @interval = ProviderRequest::INTERVALS.include?(params[:interval]) ? params[:interval] : "1h"
    @snapshot = MarketSnapshot.for(@pair.symbol, @interval)
    @candles = Candle.series(@pair.symbol, @interval).reorder(opened_at: :desc).limit(CHART_CANDLES).to_a.reverse
  end
end
