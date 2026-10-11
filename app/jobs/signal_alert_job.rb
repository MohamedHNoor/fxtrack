require "net/smtp"

# Sends one alert after final eligibility checks at dispatch time (project
# plan: pair, session and signal state are rechecked before sending).
class SignalAlertJob < ApplicationJob
  queue_as :default
  TRANSIENT = [ Net::OpenTimeout, Net::ReadTimeout, Net::SMTPServerBusy, Errno::ECONNREFUSED, Errno::ECONNRESET, SocketError ].freeze

  retry_on(*TRANSIENT, wait: :polynomially_longer, attempts: 3) do |job, error|
    job.arguments.first.finish!("failed", error_code: error.class.name, reason: "Gave up after 3 attempts")
  end
  discard_on(Net::SMTPAuthenticationError, Net::SMTPFatalError, Net::SMTPSyntaxError) do |job, error|
    job.arguments.first.finish!("failed", error_code: error.class.name, reason: "Rejected by the email provider")
  end

  def perform(delivery)
    return if %w[sent suppressed].include?(delivery.status)
    delivery.increment!(:attempts)

    reason = suppression_reason(delivery)
    return delivery.finish!("suppressed", reason: reason) if reason

    SignalMailer.with(delivery: delivery).alert.deliver_now
    delivery.finish!("sent")
  end

  private
    def suppression_reason(delivery)
      signal = delivery.trade_signal
      owner = signal.strategy_version.strategy.user
      return "Email alerts are turned off" unless NotificationPreference.for(owner).email_for?(delivery.event)
      return "No valid owner session" unless Session.active.exists?
      return "Pair disabled" unless CurrencyPair.enabled.exists?(symbol: signal.symbol)
      "Signal is no longer active" if delivery.event == "new_signal" && !signal.actionable?
    end
end
