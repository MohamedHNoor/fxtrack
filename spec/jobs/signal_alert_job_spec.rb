require "rails_helper"

RSpec.describe SignalAlertJob do
  include ActiveJob::TestHelper

  let(:user) { User.create!(email_address: "owner@example.com", password: "correct horse battery") }
  let(:preference) { NotificationPreference.for(user).tap { |p| p.update!(email_enabled: true, notify_invalidated: true) } }

  before do
    ActiveJob::Base.queue_adapter = :test
    ActionMailer::Base.deliveries.clear
    user.sessions.create!
    preference
  end

  def create_signal(symbol: "EUR/USD", expires_at: 30.minutes.from_now)
    Strategy.ensure_default_for(user)
    version = user.strategies.sole.current_version
    run = StrategyRun.create!(strategy_version: version, symbol: symbol, candle_opened_at: 1.hour.ago.beginning_of_hour, verdict: "buy", evaluated_at: Time.current)
    TradeSignal.create!(strategy_version: version, strategy_run: run, symbol: symbol, direction: "buy", source_opened_at: run.candle_opened_at,
      entry: BigDecimal("1.12900"), stop: BigDecimal("1.12410"), target: BigDecimal("1.13880"), entry_tolerance: BigDecimal("0.0004"),
      reward_ratio: 2, stop_pips: 49, planned_risk: 20, lots: BigDecimal("0.02"), risk_at_size: BigDecimal("16.5"),
      evidence: { "reasons" => [ "H4 and H1 trends are bullish" ] }, generated_at: Time.current, expires_at: expires_at)
  end

  it "queues one alert per new signal and emails the plan" do
    signal = nil
    expect { signal = create_signal }.to have_enqueued_job(described_class)
    perform_enqueued_jobs
    delivery = signal.signal_deliveries.sole
    expect(delivery).to have_attributes(status: "sent", attempts: 1, event: "new_signal")
    mail = ActionMailer::Base.deliveries.sole
    expect(mail.to).to eq([ "owner@example.com" ])
    expect(mail.from).to eq([ "info@contact.mohamedhnoor.com" ])
    expect(mail.subject).to eq("BUY EUR/USD signal at 1.12900 · FXTrack")
    expect(mail.text_part.body.to_s).to include("Stop loss:   1.12410", "0.02 lots", "/signals/#{signal.id}")

    described_class.perform_now(delivery)
    expect(ActionMailer::Base.deliveries.size).to eq(1)
    expect { SignalNotifier.notify(signal, "new_signal") }.not_to change(SignalDelivery, :count)
  end

  it "does not queue anything while email alerts are off" do
    preference.update!(email_enabled: false)
    expect { create_signal }.not_to have_enqueued_job(described_class)
  end

  it "suppresses at dispatch when the signal, pair or session is no longer eligible" do
    signal = create_signal
    delivery = signal.signal_deliveries.sole
    CurrencyPair.find_by!(symbol: "EUR/USD").update!(enabled: false)
    perform_enqueued_jobs
    expect(delivery.reload).to have_attributes(status: "suppressed", reason: "Pair disabled")

    CurrencyPair.find_by!(symbol: "EUR/USD").update!(enabled: true)
    expired = create_signal(symbol: "NZD/USD", expires_at: 1.second.from_now)
    travel 1.minute do
      perform_enqueued_jobs
    end
    expect(expired.signal_deliveries.sole.reason).to eq("Signal is no longer active")

    Session.delete_all
    later = create_signal(symbol: "AUD/USD")
    perform_enqueued_jobs
    expect(later.signal_deliveries.sole.reason).to eq("No valid owner session")
    expect(ActionMailer::Base.deliveries).to be_empty
  end

  it "alerts on invalidation when the owner opted in" do
    signal = create_signal
    perform_enqueued_jobs
    signal.close!("invalidated", "Stop level traded before entry")
    perform_enqueued_jobs
    expect(signal.signal_deliveries.find_by!(event: "invalidated").status).to eq("sent")
    expect(ActionMailer::Base.deliveries.last.subject).to eq("BUY EUR/USD signal invalidated · FXTrack")
  end

  it "retries transient failures, then records a visible failure" do
    signal = create_signal
    mailer = double(deliver_now: nil)
    allow(mailer).to receive(:deliver_now).and_raise(Net::OpenTimeout)
    allow(SignalMailer).to receive(:with).and_return(double(alert: mailer))
    # Each pass runs the jobs queued so far, including the scheduled retry.
    4.times { perform_enqueued_jobs }
    expect(signal.signal_deliveries.sole).to have_attributes(status: "failed", attempts: 3, error_code: "Net::OpenTimeout")
  end

  it "fails immediately when the provider rejects the message" do
    signal = create_signal
    mailer = double
    allow(mailer).to receive(:deliver_now).and_raise(Net::SMTPAuthenticationError.new("535 invalid key"))
    allow(SignalMailer).to receive(:with).and_return(double(alert: mailer))
    perform_enqueued_jobs
    expect(signal.signal_deliveries.sole).to have_attributes(status: "failed", attempts: 1, reason: "Rejected by the email provider")
  end

  it "freezes the HTTP payload and idempotency key across ambiguous retries" do
    signal = create_signal
    delivery = signal.signal_deliveries.sole
    allow(ActionMailer::Base).to receive(:delivery_method).and_return(:smtp)
    sender = instance_double(ResendSignalSender)
    allow(ResendSignalSender).to receive(:new).and_return(sender)
    calls = []
    allow(sender).to receive(:send) do |payload, idempotency_key:|
      calls << [ payload, idempotency_key ]
      raise ResendSignalSender::TransientError if calls.size == 1
    end
    perform_enqueued_jobs
    signal.strategy_version.strategy.update!(name: "Renamed after the first send")
    perform_enqueued_jobs
    expect(calls.size).to eq(2)
    expect(calls.first).to eq(calls.last)
    expect(delivery.reload).to have_attributes(status: "sent", attempts: 2, first_attempted_at: be_present)
  end

  it "refuses retries outside the provider idempotency window" do
    signal = create_signal
    delivery = signal.signal_deliveries.sole
    delivery.update!(first_attempted_at: 25.hours.ago)
    expect(SignalMailer).not_to receive(:with)
    described_class.perform_now(delivery)
    expect(delivery.reload).to have_attributes(status: "failed", error_code: "idempotency_window_expired")
  end

  it "reloads a stale pending delivery before sending" do
    signal = create_signal
    stale = signal.signal_deliveries.sole
    described_class.perform_now(SignalDelivery.find(stale.id))
    described_class.perform_now(stale)
    expect(ActionMailer::Base.deliveries.size).to eq(1)
  end

  context "with simultaneous workers" do
    self.use_transactional_tests = false

    it "sends one message when two workers load the same pending delivery" do
      signal = create_signal
      delivery_id = signal.signal_deliveries.sole.id
      ready, start = Queue.new, Queue.new
      threads = 2.times.map do
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            delivery = SignalDelivery.find(delivery_id)
            ready << true
            start.pop
            described_class.perform_now(delivery)
          end
        end
      end
      2.times { ready.pop }
      2.times { start << true }
      threads.each(&:value)
      expect(ActionMailer::Base.deliveries.size).to eq(1)
      expect(SignalDelivery.find(delivery_id)).to have_attributes(status: "sent", attempts: 1)
    ensure
      threads&.each(&:join)
      if user&.persisted?
        versions = StrategyVersion.where(strategy_id: user.strategies.select(:id))
        signals = TradeSignal.where(strategy_version_id: versions.select(:id))
        SignalDelivery.where(trade_signal_id: signals.select(:id)).delete_all
        signals.delete_all
        StrategyRun.where(strategy_version_id: versions.select(:id)).delete_all
        versions.delete_all
        Strategy.where(user_id: user.id).delete_all
        user.sessions.delete_all
        NotificationPreference.where(user_id: user.id).delete_all
        User.where(id: user.id).delete_all
      end
    end
  end
end
