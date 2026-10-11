class Session < ApplicationRecord
  # Owner decision 2026-10-11: expire after 7 idle days and at most 30 days.
  IDLE_TIMEOUT = 7.days
  MAX_AGE = 30.days
  # Avoid a database write on every request; activity is recorded hourly.
  ACTIVITY_PRECISION = 1.hour

  belongs_to :user

  before_validation { self.last_active_at ||= Time.current }

  scope :active, ->(now = Time.current) { where(last_active_at: (now - IDLE_TIMEOUT)..).where(created_at: (now - MAX_AGE)..) }

  def expired?(now = Time.current)
    last_active_at < now - IDLE_TIMEOUT || created_at < now - MAX_AGE
  end

  def expires_at
    [ last_active_at + IDLE_TIMEOUT, created_at + MAX_AGE ].min
  end

  def record_activity(now = Time.current)
    update_column(:last_active_at, now) if last_active_at < now - ACTIVITY_PRECISION
  end
end
