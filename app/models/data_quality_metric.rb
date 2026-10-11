class DataQualityMetric < ApplicationRecord
  belongs_to :provider_request
  validates :evaluated_at, presence: true
  validates :status, inclusion: { in: %w[valid stale gaps empty invalid unreproducible closure_unverified] }
  validates :closed_count, :incomplete_count, :duplicate_count, :gap_count, :reproduced_count, :mismatch_count,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :freshness_seconds, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :provider_request_id, uniqueness: true
end
