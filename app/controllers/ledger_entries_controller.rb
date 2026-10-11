class LedgerEntriesController < ApplicationController
  layout "app"
  before_action :set_account

  # The form takes positive amounts; withdrawals are stored as negative and an
  # adjustment's direction comes from an explicit increase/decrease choice.
  def create
    attrs = params.expect(account_ledger_entry: [ :kind, :amount, :direction, :effective_at, :notes ])
    amount = BigDecimal(attrs[:amount].to_s.strip.presence || "0") rescue BigDecimal(0)
    amount = -amount.abs if attrs[:kind] == "withdrawal" || (attrs[:kind] == "adjustment" && attrs[:direction] == "decrease")
    amount = amount.abs if attrs[:kind] == "deposit" || (attrs[:kind] == "adjustment" && attrs[:direction] != "decrease")

    @entry = @account.ledger_entries.build(kind: attrs[:kind], amount: amount, effective_at: owner_time_param(attrs[:effective_at]) || Time.current, notes: attrs[:notes])
    @entry.errors.add(:kind, "must be a deposit, withdrawal or adjustment") if attrs[:kind] == "reversal"
    if @entry.errors.none? && @entry.save
      redirect_to account_path, notice: "#{@entry.kind.capitalize} of NZD #{@entry.amount.abs} recorded."
    else
      render "accounts/show", status: :unprocessable_entity
    end
  end

  private
    def set_account
      @account = Current.user.trading_account or redirect_to(account_path, alert: "Set up the account first.")
    end
end
