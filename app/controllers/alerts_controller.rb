class AlertsController < ApplicationController
  layout "app"
  before_action :set_preference

  def show
  end

  def update
    if @preference.update(params.expect(notification_preference: [ :email_enabled, :notify_new_signal, :notify_expired, :notify_invalidated ]))
      redirect_to alerts_path, notice: "Alert settings saved."
    else
      render :show, status: :unprocessable_entity
    end
  end

  # Sends immediately so delivery problems show on the page.
  def test
    SignalMailer.with(user: Current.user).test_alert.deliver_now
    redirect_to alerts_path, status: :see_other, notice: "Test email sent to #{Current.user.email_address}#{" (written to tmp/mails in development)" if ActionMailer::Base.delivery_method == :file}."
  rescue StandardError => error
    redirect_to alerts_path, status: :see_other, alert: "Test email failed: #{error.class.name}. Check the Resend API key and sender domain."
  end

  private
    def set_preference
      @preference = NotificationPreference.for(Current.user)
      @deliveries = SignalDelivery.joins(trade_signal: { strategy_version: :strategy })
        .where(strategies: { user_id: Current.user.id }).includes(:trade_signal).recent.limit(15).to_a
    end
end
