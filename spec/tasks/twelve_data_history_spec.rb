require "rails_helper"
require "rake"

RSpec.describe "twelve_data:history" do
  before do
    Rails.application.load_tasks unless Rake::Task.task_defined?("twelve_data:history")
    Rake::Task["twelve_data:history"].reenable
    stub_const("ProviderRequest::SYMBOLS", [ "NZD/USD" ])
    stub_const("ProviderRequest::INTERVALS", [ "1h" ])
    ProviderRequest.create!(symbol: "NZD/USD", interval: "1h", endpoint: "earliest_timestamp",
      requested_at: Time.current, status: "success")
  end

  def history_request(status)
    ProviderRequest.create!(symbol: "NZD/USD", interval: "1h", endpoint: "time_series_history",
      requested_at: Time.current, status: status)
  end

  it "fetches history when an earlier successful diagnostic stored no candles" do
    history_request("success")
    probe = instance_double(TwelveData::Probe)
    allow(TwelveData::Probe).to receive(:new).and_return(probe)
    expect(probe).to receive(:run).with(symbol: "NZD/USD", interval: "1h", endpoint: "time_series_history").and_return("success")
    expect { Rake::Task["twelve_data:history"].invoke }.to output(/success/).to_stdout
  end

  it "skips successful history already stored as candles" do
    request = history_request("success")
    Candle.create!(provider_request: request, symbol: "NZD/USD", interval: "1h", opened_at: 2.hours.ago.beginning_of_hour,
      open: "0.60", high: "0.61", low: "0.59", close: "0.60")
    expect(TwelveData::Probe).not_to receive(:new)
    Rake::Task["twelve_data:history"].invoke
  end

  it "keeps rejected history final even without stored candles" do
    history_request("invalid_data")
    expect(TwelveData::Probe).not_to receive(:new)
    Rake::Task["twelve_data:history"].invoke
  end
end
