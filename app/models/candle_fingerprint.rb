class CandleFingerprint < ApplicationRecord
  belongs_to :provider_request
  validates :symbol, inclusion: { in: ProviderRequest::SYMBOLS }
  validates :interval, inclusion: { in: ProviderRequest::INTERVALS }
  validates :opened_at, presence: true, uniqueness: { scope: [ :symbol, :interval ] }
  validates :digest, format: { with: /\A[0-9a-f]{64}\z/ }
end
