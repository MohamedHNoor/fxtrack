require "rails_helper"

RSpec.describe MarketDataCollectionJob do
  it "skips collection without a valid owner session" do
    expect(TwelveData::Collection).not_to receive(:new)
    expect(described_class.perform_now).to eq(status: "no_active_session", results: [])
  end

  it "collects while a valid session exists" do
    user = User.create!(email_address: "owner@example.com", password: "correct horse battery")
    user.sessions.create!
    collection = instance_double(TwelveData::Collection, run: { status: "collected", results: [] })
    allow(TwelveData::Collection).to receive(:new).and_return(collection)
    expect(described_class.perform_now[:status]).to eq("collected")
  end

  it "treats an expired session as no session" do
    user = User.create!(email_address: "owner@example.com", password: "correct horse battery")
    user.sessions.create!(created_at: 8.days.ago, last_active_at: 8.days.ago)
    expect(TwelveData::Collection).not_to receive(:new)
    described_class.perform_now
  end
end
