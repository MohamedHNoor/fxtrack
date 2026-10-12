class PagesController < ApplicationController
  allow_unauthenticated_access

  # The landing page is for visitors; a logged-in owner belongs on the dashboard.
  def home
    redirect_to dashboard_path if authenticated?
  end
end
