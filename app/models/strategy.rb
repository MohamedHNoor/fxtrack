class Strategy < ApplicationRecord
  KINDS = { "trend_pullback" => "Trend Pullback Confirmation" }.freeze

  belongs_to :user
  has_many :versions, -> { order(:number) }, class_name: "StrategyVersion", dependent: :restrict_with_exception

  validates :name, presence: true, length: { maximum: 80 }, uniqueness: { scope: :user_id }
  validates :kind, inclusion: { in: KINDS.keys }

  scope :active, -> { where(archived_at: nil) }
  scope :running, -> { active.where(enabled: true) }

  def self.ensure_default_for(user)
    return if user.strategies.exists?
    transaction do
      strategy = user.strategies.create!(name: "Trend Pullback Confirmation V1", kind: "trend_pullback")
      strategy.versions.create!(number: 1, config: StrategyVersion::DEFAULTS)
    end
  end

  def current_version
    versions.last
  end

  def archived?
    archived_at.present?
  end

  # Editing never changes an existing version: past signals keep their rules.
  def revise!(config)
    version = versions.build(number: (versions.maximum(:number) || 0) + 1, config: config)
    version.save!
    version
  end

  def clone_as!(name)
    transaction do
      copy = user.strategies.create!(name: name, kind: kind, enabled: false)
      copy.versions.create!(number: 1, config: current_version.config)
      copy
    end
  end
end
