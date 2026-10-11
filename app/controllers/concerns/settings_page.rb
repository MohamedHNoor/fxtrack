# Loads everything the Risk & Account Settings page renders, so the risk
# settings form can re-render the page with its validation errors.
module SettingsPage
  extend ActiveSupport::Concern

  private
    def load_settings_page(trade = ActionController::Parameters.new.permit)
      @profile ||= RiskProfile.for(Current.user)
      @account = Current.user.trading_account
      @balance = @account&.balance
      @pairs = CurrencyPair.ordered
      @trade = trade
      @symbol = ProviderRequest::SYMBOLS.include?(trade[:symbol]) ? trade[:symbol] : "EUR/USD"
      @last_price = Candle.series(@symbol, "1h").last
      @nzd_usd_stored = Candle.series("NZD/USD", "1h").last
      # Prices fill from stored candles; entry and NZD/USD inputs only cover gaps.
      @result = Risk::PositionSizer.new(profile: @profile, balance: @balance || BigDecimal(0))
        .call(symbol: @symbol, entry: trade[:entry], nzd_usd: trade[:nzd_usd])
    end
end
