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

  it "rejects malformed JSON and non-object bodies without exposing them" do
    [ "secret{", '["secret"]', '"secret"', "null" ].each do |body|
      allow(http).to receive(:body).and_return(body)
      response = client.time_series(symbol: "EUR/USD", interval: "1h")
      expect(response.error_code).to eq("invalid_response")
      expect(response.inspect).not_to include("secret")
    end
  end

  it "sanitizes transport failures and HTTP server errors" do
    unavailable = described_class.new(key: -> { "secret" }, transport: ->(*) { raise SocketError, "secret" })
    response = unavailable.time_series(symbol: "EUR/USD", interval: "1h")
    expect(response.error_code).to eq("transport_error")
    expect(response.inspect).not_to include("secret")
    allow(http).to receive(:code).and_return("503")
    allow(http).to receive(:body).and_return("secret")
    response = client.time_series(symbol: "EUR/USD", interval: "1h")
    expect(response).to have_attributes(error_code: "http_error", http_status: 503, payload: nil)
    expect(response.inspect).not_to include("secret")
  end

  it "requests a bounded history window and accepts its larger body" do
    body = { status: "ok", values: [ { datetime: "x" * 300_000 } ] }.to_json
    allow(http).to receive(:body).and_return(body)
    queries = []
    client = described_class.new(key: -> { "secret" }, transport: ->(uri, _) { queries << uri.query; http })
    expect(client.time_series(symbol: "EUR/USD", interval: "4h", outputsize: 5000).status).to eq("success")
    expect(queries.last).to include("outputsize=5000")
    expect(client.time_series(symbol: "EUR/USD", interval: "4h").error_code).to eq("invalid_response")
    expect { client.time_series(symbol: "EUR/USD", interval: "4h", outputsize: 100) }.to raise_error(ArgumentError)
  end

  it "accepts earliest_timestamp bodies without a status but not explicit errors" do
    allow(http).to receive(:body).and_return('{"datetime":"2005-01-03 00:00:00","unix_time":1104710400}')
    expect(client.earliest_timestamp(symbol: "EUR/USD", interval: "1h").payload["unix_time"]).to eq(1_104_710_400)
    allow(http).to receive(:body).and_return('{"status":"error","code":400}')
    expect(client.earliest_timestamp(symbol: "EUR/USD", interval: "1h").error_code).to eq("provider_error")
  end
end
