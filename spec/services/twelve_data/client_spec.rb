require "rails_helper"

RSpec.describe TwelveData::Client do
  let(:http) { instance_double(Net::HTTPOK, code: "200", body: '{"status":"ok","values":[]}') }
  let(:transport) { ->(uri, headers) { expect(uri.query).not_to include("secret"); expect(headers["Authorization"]).to eq("apikey secret"); http } }
  let(:client) { described_class.new(key: -> { "secret" }, transport: transport) }

  before { allow(http).to receive(:[]).and_return(nil) }

  it "uses a header credential and preserves unknown credit usage" do
    response = client.time_series(symbol: "EUR/USD", interval: "1h")
    expect(response.status).to eq("success")
    expect(response.credits_used).to be_nil
  end

  it "does not expose provider error bodies" do
    allow(http).to receive(:body).and_return('{"status":"error","message":"secret"}')
    response = client.time_series(symbol: "EUR/USD", interval: "1h")
    expect(response.error_code).to eq("provider_error")
    expect(response.inspect).not_to include("secret")
  end

  it "maps rate limits and numeric retry guidance without an implicit retry" do
    allow(http).to receive(:code).and_return("429")
    allow(http).to receive(:[]).with("retry-after").and_return("60")
    response = client.time_series(symbol: "EUR/USD", interval: "1h")
    expect(response.error_code).to eq("rate_limited")
    expect(response.retry_after).to eq(60)
  end

  it "rejects a missing credential before the network" do
    client = described_class.new(key: -> { nil }, transport: ->(*) { raise "must not call" })
    expect { client.time_series(symbol: "EUR/USD", interval: "1h") }.to raise_error(ArgumentError, "Missing data_api_key credential")
  end

  it "returns a sanitized timeout" do
    client = described_class.new(key: -> { "secret" }, transport: ->(*) { raise Net::ReadTimeout, "secret" })
    expect(client.time_series(symbol: "EUR/USD", interval: "1h").error_code).to eq("timeout")
  end
end
