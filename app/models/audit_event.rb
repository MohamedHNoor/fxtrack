# Immutable record of who changed a financial record, what changed and why.
class AuditEvent < ApplicationRecord
  ACTIONS = %w[created updated corrected].freeze

  belongs_to :user
  belongs_to :auditable, polymorphic: true

  validates :action, inclusion: { in: ACTIONS }
  validates :reason, presence: true, if: -> { action == "corrected" }
  validates :reason, length: { maximum: 500 }

  before_destroy { raise ActiveRecord::ReadOnlyRecord, "Audit events are immutable" }

  def readonly?
    persisted? || super
  end
end
