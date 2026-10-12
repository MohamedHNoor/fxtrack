require "net/smtp"

# Sends one alert after final eligibility checks at dispatch time (project
# plan: pair, session and signal state are rechecked before sending).
class SignalAlertJob < ApplicationJob
  queue_as :default
  TRANSIENT = [ ResendSignalSender::TransientError, Net::OpenTimeout, Net::ReadTimeout, Net::WriteTimeout, Net::SMTPServerBusy, Errno::ECONNREFUSED, Errno::ECONNRESET, SocketError, EOFError ].freeze

  retry_on(*TRANSIENT, wait: :polynomially_longer, attempts: 3) do |job, error|
    delivery = job.arguments.first
    delivery.with_lock { delivery.finish!("failed", error_code: error.class.name, reason: "Gave up after 3 attempts") if delivery.status == "pending" }
  end
  discard_on(ResendSignalSender::PermanentError, Net::SMTPAuthenticationError, Net::SMTPFatalError, Net::SMTPSyntaxError) do |job, error|
    delivery = job.arguments.first
    delivery.with_lock { delivery.finish!("failed", error_code: error.class.name, reason: "Rejected by the email provider") if delivery.status == "pending" }
  end

  def perform(delivery)
    # Commit retry identity before contacting the provider. A process or database
    # failure after provider acceptance must not lose the original retry window.
    delivery.with_lock do
      return unless delivery.status == "pending"
      delivery.update!(first_attempted_at: Time.current) unless delivery.first_attempted_at
      if ActionMailer::Base.delivery_method == :smtp && !delivery.email_payload
        message = SignalMailer.with(delivery: delivery).alert.message
        delivery.update!(email_payload: {
          from: message[:from].to_s, to: message.to, subject: message.subject,
          html: message.html_part.body.decoded, text: message.text_part.body.decoded
        })
      end
    end
    failure = nil
    delivery.with_lock do
      return unless delivery.status == "pending"
      delivery.increment!(:attempts)
      reason = suppression_reason(delivery)
      return delivery.finish!("suppressed", reason: reason) if reason
      if delivery.first_attempted_at <= 24.hours.ago
        return delivery.finish!("failed", error_code: "idempotency_window_expired", reason: "Email retry window expired")
      end
      begin
        if ActionMailer::Base.delivery_method == :smtp
          ResendSignalSender.new.send(delivery.email_payload, idempotency_key: "fxtrack/signal/#{delivery.id}/#{delivery.created_at.utc.iso8601(6)}")
        else
          SignalMailer.with(delivery: delivery).alert.deliver_now
        end
        delivery.finish!("sent")
      rescue *TRANSIENT, ResendSignalSender::PermanentError, Net::SMTPAuthenticationError, Net::SMTPFatalError, Net::SMTPSyntaxError => error
        # Commit the frozen payload and first attempt even when sending fails.
        failure = error
      end
    end
    raise failure if failure
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
