require "rails_helper"

RSpec.describe TwelveData::MarketHours do
  it "closes Friday 17:00 to Sunday 17:00 New York time in daylight saving" do
    expect(described_class.closed?(Time.utc(2026, 10, 9, 20, 59))).to be(false)
    expect(described_class.closed?(Time.utc(2026, 10, 9, 21))).to be(true)
    expect(described_class.closed?(Time.utc(2026, 10, 11, 20, 59))).to be(true)
    expect(described_class.closed?(Time.utc(2026, 10, 11, 21))).to be(false)
  end

  it "shifts the UTC window by an hour in standard time" do
    expect(described_class.closed?(Time.utc(2026, 11, 13, 21, 59))).to be(false)
    expect(described_class.closed?(Time.utc(2026, 11, 13, 22))).to be(true)
    expect(described_class.closed?(Time.utc(2026, 11, 15, 21, 59))).to be(true)
    expect(described_class.closed?(Time.utc(2026, 11, 15, 22))).to be(false)
  end

  it "does not count weekend slots as missing candles" do
    expect(described_class.missing_opens(Time.utc(2026, 10, 9, 20), Time.utc(2026, 10, 11, 21), 3600)).to eq(0)
    expect(described_class.missing_opens(Time.utc(2026, 10, 9, 19), Time.utc(2026, 10, 11, 21), 3600)).to eq(1)
  end

  it "finds the last trading candle before the weekend" do
    expect(described_class.last_expected_open(Time.utc(2026, 10, 10, 12), 3600)).to eq(Time.utc(2026, 10, 9, 20))
    expect(described_class.next_open(Time.utc(2026, 10, 9, 21), 3600)).to eq(Time.utc(2026, 10, 11, 21))
  end
end
