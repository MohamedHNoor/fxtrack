class AccountsController < ApplicationController
  layout "app"

  def show
    @account = Current.user.trading_account
    @entry = AccountLedgerEntry.new(kind: "deposit", effective_at: Time.current) if @account
  end

  def create
    return redirect_to account_path, alert: "The account is already set up." if Current.user.trading_account

    attrs = params.expect(trading_account: [ :starting_capital, :started_at ])
    @account = Current.user.build_trading_account(starting_capital: attrs[:starting_capital], started_at: owner_time_param(attrs[:started_at]))
    if @account.save
      redirect_to account_path, notice: "Account set up with NZD #{@account.starting_capital} starting capital."
    else
      render :show, status: :unprocessable_entity
    end
  end
end
