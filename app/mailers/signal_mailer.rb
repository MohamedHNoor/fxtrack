class SignalMailer < ApplicationMailer
  helper :markets, :money

  def alert
    @delivery = params[:delivery]
    @signal = @delivery.trade_signal
    mail to: @signal.strategy_version.strategy.user.email_address, subject: subject_for(@delivery.event)
  end

  def test_alert
    @user = params[:user]
    mail to: @user.email_address, subject: "FXTrack test alert"
  end

  private
    def subject_for(event)
      pair = "#{@signal.direction.upcase} #{@signal.symbol}"
      case event
      when "new_signal" then "#{pair} signal at #{view_context.format_price(@signal.symbol, @signal.entry)} · FXTrack"
      when "expired" then "#{pair} signal expired · FXTrack"
      else "#{pair} signal invalidated · FXTrack"
      end
    end
end
