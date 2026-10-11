class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  rate_limit to: 10, within: 3.minutes, only: :create, name: "login-ip",
    with: -> { redirect_to login_path, alert: "Too many attempts. Try again in a few minutes." }
  rate_limit to: 5, within: 15.minutes, only: :create, name: "login-email",
    by: -> { params[:email_address].to_s.strip.downcase },
    with: -> { redirect_to login_path, alert: "Too many attempts. Try again in a few minutes." }

  def new
    redirect_to dashboard_path if authenticated?
  end

  def create
    if user = User.authenticate_by(params.permit(:email_address, :password))
      start_new_session_for user
      redirect_to after_authentication_url
    else
      redirect_to login_path, alert: "Try another email address or password."
    end
  end

  def destroy
    terminate_session
    redirect_to login_path, status: :see_other, notice: "You have been logged out."
  end
end
