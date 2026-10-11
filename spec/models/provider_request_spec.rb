require "rails_helper"

RSpec.describe ProviderRequest do
  let(:attributes) { { symbol: "EUR/USD", interval: "1h", endpoint: "time_series", requested_at: Time.current, status: "success" } }

  it "preserves unknown credit usage instead of reporting zero" do
    request = described_class.create!(attributes)
    expect(request.reload.credits_used).to be_nil
  end

  it "rejects unsupported instruments and unbounded error text" do
    request = described_class.new(attributes.merge(symbol: "BTC/USD", error_code: "secret response"))
    expect(request).not_to be_valid
    expect(request.errors.attribute_names).to include(:symbol, :error_code)
  end

  it "enforces credit integrity in the database" do
    request = described_class.create!(attributes)
    expect { request.update_columns(credits_used: -1) }.to raise_error(ActiveRecord::StatementInvalid)
  end
end
