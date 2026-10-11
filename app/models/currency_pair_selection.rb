# Applies the owner's pair toggles. Disabling keeps all history but stops new
# analysis and invalidates live signals; enabling warms indicator history.
class CurrencyPairSelection
  def initialize(enabled_symbols)
    @enabled = Array(enabled_symbols).map(&:to_s) & ProviderRequest::SYMBOLS
  end

  def save(now = Time.current)
    changes = { enabled: [], disabled: [] }
    CurrencyPair.transaction do
      CurrencyPair.lock.ordered.each do |pair|
        wanted = @enabled.include?(pair.symbol)
        next if pair.enabled == wanted
        pair.update!(enabled: wanted)
        changes[wanted ? :enabled : :disabled] << pair.symbol
      end
      TradeSignal.active.where(symbol: changes[:disabled]).find_each { |signal| signal.close!("invalidated", "Pair disabled", at: now) }
    end
    changes[:enabled].each { |symbol| PairWarmupJob.perform_later(symbol) }
    changes
  end
end
