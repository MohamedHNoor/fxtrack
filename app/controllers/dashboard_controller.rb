# Placeholder private page until M03 builds the market dashboard.
class DashboardController < ApplicationController
  def show
    @other_sessions = Current.user.sessions.active.where.not(id: Current.session.id).count
  end
end
