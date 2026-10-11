require "rails_helper"

RSpec.describe "Owner authentication" do
  let(:password) { "correct horse battery" }
  let!(:owner) { User.create!(email_address: "owner@example.com", password: password) }

  def log_in(email: owner.email_address, secret: password)
    post login_path, params: { email_address: email, password: secret }
  end

  it "protects private routes and returns to them after login" do
    get dashboard_path
    expect(response).to redirect_to(login_path)
    log_in
    expect(response).to redirect_to(dashboard_url)
    follow_redirect!
    expect(response.body).to include("Trading dashboard", owner.email_address)
  end

  it "sets an HttpOnly, SameSite cookie that ends within thirty days" do
    log_in
    cookie = response.headers["Set-Cookie"].then { |value| Array(value).join("\n") }[/session_id=[^\n]*/]
    expect(cookie).to include("httponly", "samesite=lax").or include("HttpOnly", "SameSite=Lax")
    expires = Time.httpdate(cookie[/expires=([^;]+)/i, 1])
    expect(expires).to be <= 30.days.from_now + 1.minute
  end

  it "rejects a wrong password without creating a session" do
    expect { log_in(secret: "wrong password!!") }.not_to change(Session, :count)
    follow_redirect!
    expect(response.body).to include("Try another email address or password.")
  end

  it "throttles repeated attempts for one email address" do
    5.times { log_in(secret: "wrong password!!") }
    log_in
    follow_redirect!
    expect(response.body).to include("Too many attempts")
    expect(Session.count).to eq(0)
  end

  it "expires a session after seven idle days" do
    log_in
    travel 8.days do
      get dashboard_path
      expect(response).to redirect_to(login_path)
    end
    expect(Session.count).to eq(0)
  end

  it "expires a session thirty days after login despite activity" do
    log_in
    [ 6, 12, 18, 24 ].each do |day|
      travel_to(day.days.from_now) { get dashboard_path; expect(response).to have_http_status(:ok) }
    end
    travel_to(31.days.from_now) { get dashboard_path; expect(response).to redirect_to(login_path) }
  end

  it "revokes the session on logout" do
    log_in
    delete logout_path
    expect(Session.count).to eq(0)
    get dashboard_path
    expect(response).to redirect_to(login_path)
  end

  it "signs out other devices but keeps the current one" do
    owner.sessions.create!
    log_in
    delete other_sessions_path
    expect(owner.sessions.count).to eq(1)
    get dashboard_path
    expect(response).to have_http_status(:ok)
  end

  it "has no public registration route" do
    get "/register"
    expect(response).to have_http_status(:not_found)
  end

  describe "password reset" do
    before { ActiveJob::Base.queue_adapter = :test }

    it "responds identically for known and unknown addresses" do
      expect { post passwords_path, params: { email_address: "OWNER@example.com" } }.to have_enqueued_mail(PasswordsMailer, :reset)
      known = flash[:notice]
      expect { post passwords_path, params: { email_address: "nobody@example.com" } }.not_to have_enqueued_mail
      expect(flash[:notice]).to eq(known)
    end

    it "updates the password with a valid token and signs out every device" do
      owner.sessions.create!
      token = owner.password_reset_token
      patch password_path(token), params: { password: "a brand new passphrase", password_confirmation: "a brand new passphrase" }
      expect(response).to redirect_to(login_path)
      expect(owner.reload.authenticate("a brand new passphrase")).to be_truthy
      expect(owner.sessions.count).to eq(0)
      patch password_path(token), params: { password: "another new passphrase", password_confirmation: "another new passphrase" }
      expect(response).to redirect_to(new_password_path)
    end

    it "rejects a short password and an expired token" do
      token = owner.password_reset_token
      patch password_path(token), params: { password: "short", password_confirmation: "short" }
      follow_redirect!
      expect(response.body).to include("Password is too short")
      travel 16.minutes do
        get edit_password_path(token)
        expect(response).to redirect_to(new_password_path)
      end
    end
  end
end
