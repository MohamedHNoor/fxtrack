class CurrencyPairsController < ApplicationController
  def update
    changes = CurrencyPairSelection.new(params.fetch(:enabled_symbols, [])).save
    summary = [ ("enabled #{changes[:enabled].to_sentence}" if changes[:enabled].any?),
                ("disabled #{changes[:disabled].to_sentence}" if changes[:disabled].any?) ].compact
    notice = summary.any? ? "Pair preferences saved: #{summary.join("; ")}." : "Pair preferences unchanged."
    notice += " Monitoring is paused until a pair is enabled." unless CurrencyPair.enabled.exists?
    redirect_to settings_path(anchor: "pairs-heading"), notice: notice
  end
end
