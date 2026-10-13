require "rails_helper"

RSpec.describe PairWarmupJob do
  let(:user) { User.create!(email_address: "owner@example.com", password: "correct horse battery") }
  let(:probe) { instance_double(TwelveData::Probe) }

  before { allow(TwelveData::Probe).to receive(:new).and_return(probe) }

  it "warms enabled pairs without a session in unattended mode" do
    user
    original = Rails.configuration.x.unattended_monitoring
    Rails.configuration.x.unattended_monitoring = true
    expect(probe).to receive(:run).with(symbol: "USD/JPY", interval: "1h", endpoint: "time_series_history")
    expect(probe).to receive(:run).with(symbol: "USD/JPY", interval: "4h", endpoint: "time_series_history")
    described_class.perform_now("USD/JPY")
    CurrencyPair.find_by!(symbol: "USD/JPY").update!(enabled: false)
    expect(probe).not_to receive(:run)
    described_class.perform_now("USD/JPY")
  ensure
    Rails.configuration.x.unattended_monitoring = original
  end

  it "fetches history windows for an enabled pair without enough candles" do
    user.sessions.create!
    expect(probe).to receive(:run).with(symbol: "USD/JPY", interval: "1h", endpoint: "time_series_history")
    expect(probe).to receive(:run).with(symbol: "USD/JPY", interval: "4h", endpoint: "time_series_history")
    described_class.perform_now("USD/JPY")
  end

  it "does nothing without a valid session or when the pair was disabled again" do
    expect(probe).not_to receive(:run)
    described_class.perform_now("USD/JPY")
    user.sessions.create!
    CurrencyPair.find_by!(symbol: "USD/JPY").update!(enabled: false)
    described_class.perform_now("USD/JPY")
  end
end
