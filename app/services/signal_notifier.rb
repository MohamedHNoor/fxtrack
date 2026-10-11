# Queues alerts for signal events the owner opted into. The delivery row is the
# idempotency key: an event is queued at most once per signal and channel.
class SignalNotifier
  def self.notify(signal, event)
    owner = signal.strategy_version.strategy.user
    return unless NotificationPreference.for(owner).email_for?(event)

    delivery = signal.signal_deliveries.create!(channel: "email", event: event)
    SignalAlertJob.perform_later(delivery)
  rescue ActiveRecord::RecordNotUnique
    nil
  end
end
