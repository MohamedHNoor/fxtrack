# Builds an owner's generated signal without running the strategy engine.
module JournalHelpers
  def journal_signal(user, symbol: "EUR/USD", direction: "buy", opened_at: Time.utc(2026, 10, 1, 10))
    Strategy.ensure_default_for(user)
    version = user.strategies.first.current_version
    run = StrategyRun.create!(strategy_version: version, symbol: symbol, candle_opened_at: opened_at, verdict: direction, evaluated_at: opened_at + 1.hour)
    entry = BigDecimal("1.1000")
    stop, target = direction == "buy" ? [ entry - BigDecimal("0.004"), entry + BigDecimal("0.008") ] : [ entry + BigDecimal("0.004"), entry - BigDecimal("0.008") ]
    TradeSignal.create!(strategy_version: version, strategy_run: run, symbol: symbol, direction: direction, source_opened_at: opened_at,
      entry: entry, stop: stop, target: target, entry_tolerance: BigDecimal("0.0005"), reward_ratio: 2, stop_pips: 40,
      generated_at: opened_at + 1.hour, expires_at: opened_at + 90.minutes)
  end
end

RSpec.configure { |config| config.include JournalHelpers }
