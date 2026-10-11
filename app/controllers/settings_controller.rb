class SettingsController < ApplicationController
  include SettingsPage
  layout "app"

  def show
    load_settings_page(params.fetch(:trade, {}).permit(:symbol, :entry, :nzd_usd))
  end
end
