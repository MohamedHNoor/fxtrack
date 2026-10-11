class OtherSessionsController < ApplicationController
  def destroy
    revoked = Current.user.sessions.where.not(id: Current.session.id).destroy_all.size
    redirect_to dashboard_path, status: :see_other, notice: "Signed out #{helpers.pluralize(revoked, "other device")}."
  end
end
