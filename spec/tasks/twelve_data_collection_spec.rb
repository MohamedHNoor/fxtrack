require "rails_helper"
require "rake"

RSpec.describe "twelve_data:collect" do
  before do
    Rails.application.load_tasks unless Rake::Task.task_defined?("twelve_data:collect")
    Rake::Task["twelve_data:collect"].reenable
  end

  it "reports partial failures as a nonzero operator result" do
    result = { status: "partial_failure", results: [ { symbol: "NZD/USD", interval: "1h", status: "provider_failure" } ] }
    allow(TwelveData::Collection).to receive(:new).and_return(instance_double(TwelveData::Collection, run: result))
    expect do
      expect do
        expect { Rake::Task["twelve_data:collect"].invoke }.to raise_error(SystemExit) { |error| expect(error.status).to eq(1) }
      end.to output(/partial_failure/).to_stdout
    end.to output(/Collection had failures/).to_stderr
  end

  it "prints successful collection without aborting" do
    result = { status: "collected", results: [] }
    allow(TwelveData::Collection).to receive(:new).and_return(instance_double(TwelveData::Collection, run: result))
    expect { Rake::Task["twelve_data:collect"].invoke }.to output(/collected/).to_stdout
  end
end
