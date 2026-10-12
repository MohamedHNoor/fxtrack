require "rails_helper"

RSpec.describe ResendSignalSender do
  let(:payload) { { "from" => "owner@example.com", "to" => [ "owner@example.com" ], "subject" => "Signal", "text" => "Plan" } }

  def sender(code, body)
    described_class.new(key: -> { "secret" }, transport: ->(sent, key, idempotency_key) {
      expect(sent).to eq(payload)
      expect(key).to eq("secret")
      expect(idempotency_key).to eq("signal/1")
      Struct.new(:code, :body).new(code.to_s, body)
    })
  end

  it "accepts successful provider acknowledgements" do
    expect { sender(200, '{"id":"email-1"}').send(payload, idempotency_key: "signal/1") }.not_to raise_error
  end

  it "sends JSON and authentication/idempotency headers over HTTPS" do
    http = double
    expect(Net::HTTP).to receive(:start).with("api.resend.com", 443, use_ssl: true, open_timeout: 5, read_timeout: 10, write_timeout: 5, max_retries: 0).and_yield(http)
    expect(http).to receive(:request) do |request|
      expect(request.path).to eq("/emails")
      expect(request["Authorization"]).to eq("Bearer secret")
      expect(request["Idempotency-Key"]).to eq("signal/1")
      expect(JSON.parse(request.body)).to eq(payload)
      Struct.new(:code, :body).new("200", '{"id":"email-1"}')
    end
    described_class.new(key: -> { "secret" }).send(payload, idempotency_key: "signal/1")
  end

  it "fails missing credentials before making a request" do
    transport = double
    expect(transport).not_to receive(:call)
    expect { described_class.new(key: -> { nil }, transport: transport).send(payload, idempotency_key: "signal/1") }.to raise_error(described_class::PermanentError)
  end

  it "retries rate limits, server errors, concurrent keys and malformed success bodies" do
    [ [ 429, "secret" ], [ 503, "secret" ], [ 409, '{"name":"concurrent_idempotent_requests"}' ], [ 200, "secret{" ] ].each do |code, body|
      expect { sender(code, body).send(payload, idempotency_key: "signal/1") }.to raise_error(described_class::TransientError) { |e| expect(e.message).not_to include("secret") }
    end
  end

  it "does not retry rejected credentials or mismatched idempotent payloads" do
    [ 401, 422, 409 ].each do |code|
      expect { sender(code, "secret").send(payload, idempotency_key: "signal/1") }.to raise_error(described_class::PermanentError) { |e| expect(e.message).not_to include("secret") }
    end
  end
end
