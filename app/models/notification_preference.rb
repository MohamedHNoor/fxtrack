class NotificationPreference < ApplicationRecord
  EVENTS = { "new_signal" => :notify_new_signal, "expired" => :notify_expired, "invalidated" => :notify_invalidated }.freeze

  belongs_to :user

  # Unsaved defaults (alerts off) until the owner saves, so viewing never writes.
  def self.for(user)
    find_or_initialize_by(user: user)
  end

  def email_for?(event)
    email_enabled && public_send(EVENTS.fetch(event))
  end
end
