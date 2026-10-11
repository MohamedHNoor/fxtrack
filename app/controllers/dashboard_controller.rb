class DashboardController < ApplicationController
  layout "app"

  def show
    @pairs = CurrencyPair.enabled.ordered
    @snapshots = @pairs.to_h { |pair| [ pair.symbol, ProviderRequest::INTERVALS.to_h { |interval| [ interval, MarketSnapshot.for(pair.symbol, interval) ] } ] }
    @active_sessions = Session.active.count
    @other_sessions = Current.user.sessions.active.where.not(id: Current.session.id).count
    @last_request = ProviderRequest.where(endpoint: "time_series").order(:requested_at, :id).last
    @latest_close = Candle.where(symbol: @pairs.map(&:symbol), interval: "1h").maximum(:opened_at)&.then { |opened| opened + 1.hour }
  end
end
