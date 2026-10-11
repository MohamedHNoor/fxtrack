class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  # bcrypt ignores bytes beyond 72, so longer passwords would be silently truncated.
  validates :password, length: { minimum: 12, maximum: 72 }, allow_nil: true
  validate :sole_owner, on: :create

  private
    def sole_owner
      errors.add(:base, "FXTrack already has an owner") if User.exists?
    end
end
