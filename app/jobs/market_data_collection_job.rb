# Monitoring runs only while at least one valid owner session exists
# (project plan: closing a browser does not stop it; expiry or logout does).
class MarketDataCollectionJob < ApplicationJob
  queue_as :default

  def perform
    return { status: "no_active_session", results: [] } unless Session.active.exists?
    TwelveData::Collection.new.run
  end
end
