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

  it "does not analyse after the last session is revoked during collection" do
    user = User.create!(email_address: "owner@example.com", password: "correct horse battery")
    user.sessions.create!
    collection = instance_double(TwelveData::Collection)
    allow(TwelveData::Collection).to receive(:new).and_return(collection)
    allow(collection).to receive(:run) { Session.delete_all; { status: "collected", results: [] } }
    expect(Strategies::SignalEngine).not_to receive(:new)
    described_class.perform_now
  end
end

RSpec.describe MarketDataCollectionJob, "pair eligibility" do
  let(:user) { User.create!(email_address: "owner@example.com", password: "correct horse battery") }

  before { user.sessions.create! }

  around do |example|
    original = Rails.configuration.x.collect_all_pairs
    example.run
    Rails.configuration.x.collect_all_pairs = original
  end

  it "collects every pair while M00 evidence is gathered" do
    Rails.configuration.x.collect_all_pairs = true
    CurrencyPair.where.not(symbol: "EUR/USD").update_all(enabled: false)
    expect(TwelveData::Collection).to receive(:new).with(symbols: ProviderRequest::SYMBOLS).and_return(double(run: { status: "collected", results: [] }))
    described_class.perform_now
  end

  it "collects only enabled pairs afterwards and pauses with none" do
    Rails.configuration.x.collect_all_pairs = false
    CurrencyPair.where.not(symbol: %w[EUR/USD NZD/USD]).update_all(enabled: false)
    expect(TwelveData::Collection).to receive(:new).with(symbols: %w[EUR/USD NZD/USD]).and_return(double(run: { status: "collected", results: [] }))
    described_class.perform_now
    CurrencyPair.update_all(enabled: false)
    expect(described_class.perform_now).to eq(status: "no_enabled_pairs", results: [])
  end
end
