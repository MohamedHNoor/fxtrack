require "rails_helper"

RSpec.describe "Landing page" do
  it "renders the public landing page with SEO metadata" do
    get root_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("<title>FXTrack · Private forex decision support</title>")
    expect(response.body).to include('name="description"', 'property="og:title"', 'rel="canonical"')
    expect(response.body).to include('id="features"', 'id="how"', 'id="faq"')
  end

  it "offers a login call to action and no public signup" do
    get root_path
    expect(response.body).to include(%(href="#{login_path}"))
    expect(response.body).not_to match(/sign ?up|register|create an account now/i)
  end

  it "labels the preview as illustrative and reads no provider data" do
    queries = []
    callback = ->(*, payload) { queries << payload[:sql] }
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { get root_path }
    expect(response.body).to include("ILLUSTRATIVE", "not market data")
    expect(queries.grep(/provider_requests|data_quality_metrics|candle_fingerprints/)).to be_empty
  end

  it "provides an accessible mobile navigation drawer" do
    get root_path
    expect(response.body).to include('aria-controls="mobile-menu"', 'aria-haspopup="dialog"', 'aria-expanded="false"')
    expect(response.body).to match(/<dialog id="mobile-menu" aria-label="Menu"/)
    expect(response.body).to include("Close menu")
  end

  it "keeps the login placeholder out of search indexes" do
    get login_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('name="robots" content="noindex"')
  end

  context "when the owner is logged in" do
    let!(:owner) { User.create!(email_address: "owner@example.com", password: "correct horse battery") }

    before { post login_path, params: { email_address: owner.email_address, password: "correct horse battery" } }

    it "sends the owner from the landing page to the dashboard" do
      get root_path
      expect(response).to redirect_to(dashboard_path)
      get login_path
      expect(response).to redirect_to(dashboard_path)
    end

    it "offers the dashboard instead of login on public pages" do
      get new_password_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(%(href="#{dashboard_path}">Dashboard</a>))
      expect(response.body).not_to include(%(href="#{login_path}">Login</a>))
    end
  end

  it "shows Login to logged-out visitors" do
    get new_password_path
    expect(response.body).to include(%(href="#{login_path}">Login</a>))
  end
end
