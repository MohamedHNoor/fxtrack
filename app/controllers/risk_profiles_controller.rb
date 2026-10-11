class RiskProfilesController < ApplicationController
  include SettingsPage
  layout "app"

  def update
    @profile = RiskProfile.for(Current.user)
    if @profile.update(params.expect(risk_profile: [ :mode, :risk_percent, :fixed_risk, :reward_ratio, :stop_pips, :max_loss, :min_lot, :lot_step ]))
      redirect_to settings_path, notice: "Risk settings saved."
    else
      load_settings_page
      render "settings/show", status: :unprocessable_entity
    end
  end
end
