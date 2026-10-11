require "rails_helper"

RSpec.describe TwelveData::Probe do
  let(:now) { Time.utc(2026, 10, 12, 12) }
  let(:client) { instance_double(TwelveData::Client) }
  let(:failure) { TwelveData::Client::Response.new(status: "provider_failure", http_status: nil, credits_used: nil, credits_left: nil, error_code: "timeout", payload: nil, retry_after: nil) }

  it "records each bounded retry with unknown credits and redacted errors" do
    allow(client).to receive(:time_series).and_return(failure)
    sleeps = []
    probe = described_class.new(client: client, clock: -> { now }, sleeper: ->(seconds) { sleeps << seconds })
    expect { probe.run(symbol: "EUR/USD", interval: "1h") }.to change(ProviderRequest, :count).by(3)
    expect(sleeps).to eq([ 2, 4 ])
    expect(ProviderRequest.pluck(:error_code).uniq).to eq([ "timeout" ])
    expect(ProviderRequest.where(credits_used: nil).count).to eq(3)
  end

  it "reserves headroom and pauses before making another request" do
    7.times { ProviderRequest.create!(symbol: "EUR/USD", interval: "1h", endpoint: "time_series", requested_at: now, status: "reserved") }
    expect(client).not_to receive(:time_series)
    probe = described_class.new(client: client, clock: -> { now })
    expect(probe.run(symbol: "EUR/USD", interval: "1h")).to eq("quota_paused")
  end

  it "does not sleep beyond its bounded retry window" do
    response = failure.with(error_code: "rate_limited", http_status: 429, retry_after: 120)
    allow(client).to receive(:time_series).and_return(response)
    sleeper = spy("sleeper")
    probe = described_class.new(client: client, clock: -> { now }, sleeper: sleeper)
    expect(probe.run(symbol: "EUR/USD", interval: "1h")).to eq("provider_failure")
    expect(sleeper).not_to have_received(:call)
  end
end
