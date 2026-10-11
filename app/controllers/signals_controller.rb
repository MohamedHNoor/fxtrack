class SignalsController < ApplicationController
  layout "app"

  def index
    Strategy.ensure_default_for(Current.user)
    signals = owner_signals.includes(strategy_version: :strategy)
    @active = signals.active.where("trade_signals.expires_at > ?", Time.current).recent.to_a
    @history = signals.where.not(id: @active.map(&:id)).recent.limit(20)
    @latest_runs = latest_runs
  end

  def show
    @signal = owner_signals.find(params[:id])
  end

  private
    def owner_signals
      TradeSignal.joins(strategy_version: :strategy).where(strategies: { user_id: Current.user.id })
    end

    # Most recent verdict per enabled pair for each running strategy.
    def latest_runs
      versions = Current.user.strategies.running.map(&:current_version).compact
      CurrencyPair.enabled.ordered.flat_map do |pair|
        versions.map { |version| [ pair, version, version.runs.where(symbol: pair.symbol).order(:candle_opened_at).last ] }
      end
    end
end
