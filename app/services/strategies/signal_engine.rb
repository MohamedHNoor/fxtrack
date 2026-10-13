module Strategies
  # Evaluates running strategies on each enabled pair's latest completed H1
  # candle and maintains signal lifecycles. Only fresh data is analysed, so
  # restarts and late data never create retroactive signals (project plan).
  class SignalEngine
    CANDLES = 300

    def initialize(clock: -> { Time.current })
      @clock = clock
    end

    def run
      now = @clock.call
      user = User.first or return { runs: 0, signals: 0 }
      return { runs: 0, signals: 0 } unless user.monitoring_active?(now)
      update_lifecycles(now)
      Strategy.ensure_default_for(user)
      profile = RiskProfile.for(user)
      balance = user.trading_account&.balance || BigDecimal(0)
      created = { runs: 0, signals: 0 }

      Strategy.running.where(user: user).find_each do |strategy|
        version = strategy.current_version
        CurrencyPair.enabled.ordered.each do |pair|
          outcome = evaluate(version, pair.symbol, profile, balance, now)
          created[:runs] += 1 if outcome
          created[:signals] += 1 if outcome == :signal
        end
      end
      created
    end

    private
      def evaluate(version, symbol, profile, balance, now)
        return unless version.strategy.user.monitoring_active?(@clock.call)
        h1 = Candle.series(symbol, "1h").last(CANDLES)
        latest = h1.last
        return unless latest && MarketSnapshot.for(symbol, "1h", now: now).state == :fresh
        return if StrategyRun.exists?(strategy_version: version, symbol: symbol, candle_opened_at: latest.opened_at)

        h4 = Candle.series(symbol, "4h").last(CANDLES)
        verdict = TrendPullback.new(config: version.config, reward_ratio: profile.reward_ratio, pip_size: CurrencyPair.pip_size(symbol))
          .evaluate(h4: h4, h1: h1)
        h4_snapshot = MarketSnapshot.for(symbol, "4h", now: now)
        if verdict.trade? && (h4_snapshot.state != :fresh || h4_snapshot.last_request&.status == "invalid_data")
          verdict = TrendPullback::Verdict.new(direction: nil, reasons: [ "H4 data is not fresh; waiting for current trend evidence" ],
            entry: nil, stop: nil, target: nil, tolerance: nil, evidence: verdict.evidence)
        end
        expires_at = latest.closed_at + version.setting("expiry_minutes").minutes

        TradeSignal.transaction do
          # Revocation/deletion of this eligible session waits until persistence
          # finishes, so logout and signal creation have a defined order.
          unless Rails.configuration.x.unattended_monitoring
            return unless version.strategy.user.sessions.active(@clock.call).order(:id).lock.first
          end
          return unless CurrencyPair.enabled.where(symbol: symbol).lock.first
          run = StrategyRun.create!(strategy_version: version, symbol: symbol, candle_opened_at: latest.opened_at, evaluated_at: now,
            verdict: verdict.direction || "wait", explanation: { "reasons" => verdict.reasons, "evidence" => verdict.evidence })
          if verdict.trade? && expires_at > now
            create_signal(version, run, symbol, verdict, profile, balance, now, expires_at, latest)
            :signal
          else
            :run
          end
        end
      rescue ActiveRecord::RecordNotUnique
        nil
      end

      def create_signal(version, run, symbol, verdict, profile, balance, now, expires_at, latest)
        stop_pips = ((verdict.entry - verdict.stop).abs / CurrencyPair.pip_size(symbol)).round(1)
        sizing = Risk::PositionSizer.new(profile: profile, balance: balance)
          .call(symbol: symbol, entry: verdict.entry, stop_pips: stop_pips, cost_pips: version.setting("spread_pips"))
        TradeSignal.create!(strategy_version: version, strategy_run: run, symbol: symbol, direction: verdict.direction,
          source_opened_at: latest.opened_at, entry: verdict.entry, stop: verdict.stop, target: verdict.target,
          entry_tolerance: verdict.tolerance, reward_ratio: profile.reward_ratio, stop_pips: stop_pips,
          planned_risk: sizing.planned_risk, lots: sizing.lots, risk_at_size: sizing.risk_at_size, sizing_error: sizing.errors.first,
          evidence: verdict.evidence.merge("reasons" => verdict.reasons, "sizing_steps" => sizing.steps),
          generated_at: now, expires_at: expires_at)
      end

      # Countdown alone does not establish validity: newer candles can break the
      # setup before expiry.
      def update_lifecycles(now)
        TradeSignal.active.where(expires_at: ..now).find_each { |signal| signal.close!("expired", "Expired without a new entry", at: now) }
        TradeSignal.active.find_each do |signal|
          newer = Candle.series(signal.symbol, "1h").where(opened_at: (signal.source_opened_at + 1.second)..)
          next if newer.empty?
          buy = signal.direction == "buy"
          if newer.any? { |candle| buy ? candle.low <= signal.stop : candle.high >= signal.stop }
            signal.close!("invalidated", "Stop level traded before entry", at: now)
          elsif (newer.last.close - signal.entry).abs > signal.entry_tolerance
            signal.close!("invalidated", "Price moved beyond the entry tolerance", at: now)
          end
        end
      end
  end
end
