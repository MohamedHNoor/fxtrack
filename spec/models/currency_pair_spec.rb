require "rails_helper"

RSpec.describe CurrencyPair do
  it "seeds the seven supported pairs, all enabled, in order" do
    expect(described_class.ordered.pluck(:symbol)).to eq(ProviderRequest::SYMBOLS)
    expect(described_class.enabled.count).to eq(7)
  end

  it "round-trips URL parameters and rejects malformed ones" do
    pair = described_class.find_by!(symbol: "USD/JPY")
    expect(pair.to_param).to eq("USDJPY")
    expect(described_class.find_by_param!("usdjpy")).to eq(pair)
    expect { described_class.find_by_param!("X") }.to raise_error(ActiveRecord::RecordNotFound)
    expect { described_class.find_by_param!("ABCDEF") }.to raise_error(ActiveRecord::RecordNotFound)
  end
end
