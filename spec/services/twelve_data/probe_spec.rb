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

  it "does not sum cumulative minute credit headers as request costs" do
    [ 1, 2, 3 ].each do |used|
      ProviderRequest.create!(symbol: "EUR/USD", interval: "1h", endpoint: "time_series", requested_at: now,
        status: "success", credits_used: used, credits_left: 8 - used)
    end
    allow(client).to receive(:time_series).and_return(failure.with(error_code: "provider_error"))
    expect(described_class.new(client: client, clock: -> { now }).run(symbol: "EUR/USD", interval: "1h")).to eq("provider_failure")
    expect(ProviderRequest.count).to eq(4)
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

RSpec.describe "Catalogue probing" do
  it "records catalogue evidence without a candle interval" do
    client = instance_double(TwelveData::Client)
    response = TwelveData::Client::Response.new(status: "success", http_status: 200, credits_used: 1,
      credits_left: 7, error_code: nil, payload: { "data" => [ { "symbol" => "EUR/USD" } ] }, retry_after: nil)
    expect(client).to receive(:forex_pairs).with(symbol: "EUR/USD").and_return(response)
    status = TwelveData::Probe.new(client: client).run(symbol: "EUR/USD", endpoint: "forex_pairs")
    expect(status).to eq("success")
    expect(ProviderRequest.last).to have_attributes(endpoint: "forex_pairs", interval: nil, credits_used: 1)
    expect(DataQualityMetric.count).to eq(0)
  end

  it "rejects a catalogue response missing the requested symbol" do
    client = instance_double(TwelveData::Client)
    response = TwelveData::Client::Response.new(status: "success", http_status: 200, credits_used: 1,
      credits_left: 7, error_code: nil, payload: { "data" => [] }, retry_after: nil)
    allow(client).to receive(:forex_pairs).and_return(response)
    expect(TwelveData::Probe.new(client: client).run(symbol: "EUR/USD", endpoint: "forex_pairs")).to eq("invalid_data")
  end
end

RSpec.describe "Concurrent probe quota", type: :model do
  self.use_transactional_tests = false

  it "limits concurrent workers to the shared seven-credit budget" do
    now = Time.utc(2030, 1, 1, 12)
    response = TwelveData::Client::Response.new(status: "provider_failure", http_status: 503, credits_used: nil,
      credits_left: nil, error_code: "http_error", payload: nil, retry_after: nil)
    client = Object.new
    client.define_singleton_method(:time_series) { |**_| response }
    threads = 4.times.map do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          TwelveData::Probe.new(client: client, clock: -> { now }, sleeper: ->(_) { }).run(symbol: "EUR/USD", interval: "1h")
        end
      end
    end
    threads.each(&:value)
    expect(ProviderRequest.where(requested_at: now).count).to eq(7)
  ensure
    threads&.each(&:join)
    ProviderRequest.where(requested_at: now).delete_all if now
  end
end
