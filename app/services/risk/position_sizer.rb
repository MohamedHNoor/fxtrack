module Risk
  # Sizes a position from the owner's risk settings and one pair:
  #   risk (NZD)      = balance x risk % (or fixed NZD), capped by max loss
  #   risk (USD)      = risk (NZD) x NZD/USD
  #   pip value (USD) = pip size x 100,000 x USD per quote unit, per standard lot
  #   lots            = risk (USD) / (stop pips x pip value), rounded down to the lot step
  # Rounding down keeps the loss at or below plan. Trading costs, slippage and
  # conversion fees are excluded, and gaps can exceed the stop.
  class PositionSizer
    LOT_UNITS = 100_000

    Plan = Data.define(:direction, :entry, :stop, :target)
    Result = Data.define(:errors, :entry, :planned_risk, :lots, :units, :risk_at_size, :reward_at_size, :plans, :sources, :steps) do
      def ok? = errors.empty?
    end

    def initialize(profile:, balance:, conversion: Conversion.new)
      @profile, @balance, @conversion = profile, balance, conversion
    end

    # entry and nzd_usd are optional overrides, used only when no stored price
    # exists. Signals pass their own stop distance and assumed spread.
    def call(symbol:, entry: nil, nzd_usd: nil, stop_pips: nil, cost_pips: 0)
      return failure([ "Unsupported currency pair" ]) unless ProviderRequest::SYMBOLS.include?(symbol)
      return failure([ "Set up the account on the Account page; risk is a share of its balance" ]) unless @balance.positive?

      entry = number(entry) || @conversion.last_close(symbol)&.close
      return failure([ "No #{symbol} price is stored yet. Enter the current price." ]) unless entry&.positive?
      rate = @conversion.for(symbol, entry: entry, nzd_usd: number(nzd_usd))
      return failure([ "No NZD/USD rate is stored yet. Enter the current NZD/USD rate." ]) unless rate

      planned = @profile.planned_risk(@balance)
      return failure([ "Planned risk exceeds the account balance" ]) if planned > @balance

      pip_size = CurrencyPair.pip_size(symbol)
      stop_pips = number(stop_pips) || @profile.stop_pips
      cost_pips = number(cost_pips) || BigDecimal(0)
      distance_pips = stop_pips + cost_pips
      usd_risk = (planned * rate.nzd_usd).round(2)
      usd_pip_value = (pip_size * LOT_UNITS * rate.usd_per_quote).round(2)
      raw_lots = usd_risk / (distance_pips * usd_pip_value)
      lots = (raw_lots.round(8) / @profile.lot_step).floor * @profile.lot_step
      if lots < @profile.min_lot
        return failure([ "The position would be #{raw_lots.round(4).to_s("F")} lots, below your broker minimum of #{@profile.min_lot.to_s("F")}. Increase the risk or reduce the stop distance." ])
      end

      risk_at_size = (lots * distance_pips * usd_pip_value / rate.nzd_usd).round(2)
      distance = stop_pips * pip_size
      plans = { "buy" => Plan.new("buy", entry, entry - distance, entry + distance * @profile.reward_ratio),
                "sell" => Plan.new("sell", entry, entry + distance, entry - distance * @profile.reward_ratio) }
      Result.new(errors: [], entry: entry, planned_risk: planned, lots: lots, units: (lots * LOT_UNITS).to_i, risk_at_size: risk_at_size,
        reward_at_size: (risk_at_size * @profile.reward_ratio).round(2), plans: plans, sources: rate.sources,
        steps: explain(symbol, entry, planned, rate, usd_risk, stop_pips, cost_pips, usd_pip_value, raw_lots, lots, risk_at_size))
    rescue ArgumentError, TypeError
      failure([ "Prices must be numbers, for example 1.12025" ])
    end

    private
      def number(value)
        BigDecimal(value.to_s.strip) if value.present?
      end

      def nzd(amount) = ActiveSupport::NumberHelper.number_to_currency(amount, unit: "NZ$", precision: 2)
      def usd(amount) = ActiveSupport::NumberHelper.number_to_currency(amount, unit: "US$", precision: 2)
      def plain(value) = value.to_s("F").sub(/\.0\z/, "")

      def explain(symbol, entry, planned, rate, usd_risk, stop_pips, cost_pips, usd_pip_value, raw_lots, lots, risk_at_size)
        risk = if @profile.mode == "fixed"
          "Fixed risk per trade: #{nzd(planned)}"
        else
          "Risking #{plain(@profile.risk_percent)}% of #{nzd(@balance)}: #{plain(@balance.round(2))} x #{plain(@profile.risk_percent / 100)} = #{nzd(planned)}"
        end
        risk += " (capped by your maximum loss)" if @profile.max_loss && planned == @profile.max_loss
        pip_basis = symbol.end_with?("/USD") ? "" : " at #{symbol} #{plain(entry)}"
        steps = [
          risk,
          "NZ$1 = US$#{plain(rate.nzd_usd)}, so the US-dollar risk budget is #{plain(planned)} x #{plain(rate.nzd_usd)} = #{usd(usd_risk)}",
          "With a #{plain(stop_pips)}-pip stop#{" plus #{plain(cost_pips)} pips of spread" if cost_pips.positive?} and a #{symbol} standard-lot pip value of #{usd(usd_pip_value)}#{pip_basis}:",
          "Lots = #{plain(usd_risk)} / (#{plain(stop_pips + cost_pips)} x #{plain(usd_pip_value)}) = #{raw_lots.round(4).to_s("F")}"
        ]
        steps << "Rounded down to your #{plain(@profile.lot_step)} lot step: #{plain(lots)} lots" if lots != raw_lots.round(4)
        steps << "At #{plain(lots)} lots, a #{plain(stop_pips)}-pip adverse move costs approximately #{nzd(risk_at_size)}, excluding trading costs, slippage and currency conversion fees."
      end

      def failure(errors)
        Result.new(errors: errors, entry: nil, planned_risk: nil, lots: nil, units: nil, risk_at_size: nil, reward_at_size: nil,
          plans: {}, sources: [], steps: [])
      end
  end
end
