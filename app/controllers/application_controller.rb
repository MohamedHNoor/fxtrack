class ApplicationController < ActionController::Base
  include Authentication
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  private
    # datetime-local fields carry no zone; read them as owner wall-clock time.
    def owner_time_param(value)
      Time.find_zone!(Rails.configuration.x.owner_time_zone).parse(value.to_s) if value.present?
    end
end
