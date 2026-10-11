module Risk
  # Rates needed to size a trade without assuming a fixed pip value (project
  # plan, risk rules): NZD/USD turns the NZD risk budget into USD, and the
  # USD value of one quote-currency unit prices the pip. USD-quoted pairs need
  # no quote rate; USD/xxx pairs use their own price; NZD/USD uses itself.
  class Conversion
    Rate = Data.define(:nzd_usd, :usd_per_quote, :sources)

    def initialize(rates: nil)
      @rates = rates
    end

    def for(symbol, entry:, nzd_usd: nil)
      nzd_usd_rate, nzd_usd_source = nzd_usd_for(symbol, entry, nzd_usd)
      return unless nzd_usd_rate

      if symbol.end_with?("/USD")
        Rate.new(nzd_usd_rate, BigDecimal(1), [ nzd_usd_source ])
      else
        Rate.new(nzd_usd_rate, 1 / entry, [ nzd_usd_source, "#{symbol} #{entry.to_s("F")} (entry price)" ])
      end
    end

    def last_close(symbol)
      @rates ? @rates[symbol] : Candle.series(symbol, "1h").last
    end

    private
      def nzd_usd_for(symbol, entry, manual)
        return [ entry, "NZD/USD #{entry.to_s("F")} (entry price)" ] if symbol == "NZD/USD"
        return [ manual, "NZD/USD #{manual.to_s("F")} (entered)" ] if manual&.positive?
        stored = last_close("NZD/USD")
        [ stored.close, "NZD/USD #{stored.close.to_s("F")} (last stored close)" ] if stored
      end
  end
end
