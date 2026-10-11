require "rails_helper"

RSpec.describe "Application health", type: :request do
  it "reports a successfully booted application" do
    get "/up"

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/html")
  end
end
