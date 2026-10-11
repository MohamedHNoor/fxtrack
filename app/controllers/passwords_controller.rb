class PasswordsController < ApplicationController
  allow_unauthenticated_access
  before_action :set_user_by_token, only: %i[ edit update ]
  rate_limit to: 10, within: 3.minutes, only: :create, name: "reset-ip",
    with: -> { redirect_to new_password_path, alert: "Too many requests. Try again later." }
  rate_limit to: 3, within: 1.hour, only: :create, name: "reset-email",
    by: -> { params[:email_address].to_s.strip.downcase },
    with: -> { redirect_to new_password_path, alert: "Too many requests. Try again later." }

  def new
  end

  def create
    if user = User.find_by(email_address: params[:email_address].to_s.strip.downcase)
      PasswordsMailer.reset(user).deliver_later
    end

    # Identical response whether or not the address exists, to avoid enumeration.
    redirect_to login_path, notice: "If that address belongs to the owner, a reset link is on its way."
  end

  def edit
  end

  def update
    if @user.update(params.permit(:password, :password_confirmation))
      @user.sessions.destroy_all
      redirect_to login_path, notice: "Password updated. Log in with your new password."
    else
      redirect_to edit_password_path(params[:token]), alert: @user.errors.full_messages.to_sentence
    end
  end

  private
    def set_user_by_token
      @user = User.find_by_password_reset_token!(params[:token])
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      redirect_to new_password_path, alert: "That reset link is invalid or has expired."
    end
end
