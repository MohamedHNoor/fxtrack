require "rails_helper"

RSpec.describe "Markets" do
  let!(:owner) { User.create!(email_address: "owner@example.com", password: "correct horse battery") }

  before do
    request = ProviderRequest.create!(symbol: "EUR/USD", interval: "1h", endpoint: "time_series", requested_at: Time.current, status: "success")
    [ 2, 1 ].each do |hours_ago|
      Candle.create!(provider_request: request, symbol: "EUR/USD", interval: "1h", opened_at: (hours_ago + 1).hours.ago.beginning_of_hour,
        open: 1.16, high: 1.17, low: 1.15, close: 1.16 + hours_ago / 1000.0)
    end
  end

  def log_in
    post login_path, params: { email_address: owner.email_address, password: "correct horse battery" }
  end

  it "requires login" do
    get markets_path
    expect(response).to redirect_to(login_path)
  end

  it "keeps private pages protected and explains unattended monitoring" do
    original = Rails.configuration.x.unattended_monitoring
    Rails.configuration.x.unattended_monitoring = true
    get dashboard_path
    expect(response).to redirect_to(login_path)
    log_in
    get dashboard_path
    expect(response.body).to include("Unattended monitoring enabled", "Monitoring continues after logout.")
  ensure
    Rails.configuration.x.unattended_monitoring = original
  end

  it "lists enabled pairs with stored prices and empty states" do
    log_in
    get markets_path
    expect(response.body).to include("EUR/USD", "1.16100", "GBP/USD", "No data yet")
  end

  it "renders a chart with stored candles for the chosen interval" do
    log_in
    get market_path("EURUSD")
    expect(response.body).to include('data-controller="candlestick-chart"', "Completed candles")
    get market_path("EURUSD", interval: "4h")
    expect(response.body).to include("No candles stored yet")
  end

  it "returns 404 for an unknown pair" do
    log_in
    get market_path("XXXYYY")
    expect(response).to have_http_status(:not_found)
  end

  it "shows the dashboard summaries and honest empty states" do
    log_in
    get dashboard_path
    expect(response.body).to include("Watchlist", "Monitoring status", "Not set up", "Strategies analyse each completed H1 candle.")
  end
end
