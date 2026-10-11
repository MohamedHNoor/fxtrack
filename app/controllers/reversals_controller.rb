class ReversalsController < ApplicationController
  def create
    entry = Current.user.trading_account&.ledger_entries&.find(params[:ledger_entry_id])
    return head :not_found unless entry
    return redirect_to(account_path, alert: "That entry cannot be reversed.") unless entry.reversible?

    entry.reverse!
    redirect_to account_path, status: :see_other, notice: "#{entry.kind.capitalize} reversed."
  end
end
