class SignalDelivery < ApplicationRecord
  STATUSES = %w[pending sent failed suppressed].freeze

  belongs_to :trade_signal

  validates :channel, inclusion: { in: %w[email] }
  validates :event, inclusion: { in: NotificationPreference::EVENTS.keys }
  validates :status, inclusion: { in: STATUSES }

  scope :recent, -> { order(updated_at: :desc) }

  def finish!(status, reason: nil, error_code: nil)
    update!(status: status, reason: reason, error_code: error_code, sent_at: (Time.current if status == "sent"))
  end
end
