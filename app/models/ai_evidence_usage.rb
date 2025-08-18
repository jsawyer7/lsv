class AiEvidenceUsage < ApplicationRecord
  belongs_to :user

  validates :used_at, presence: true
  validates :feature_type, presence: true
  validates :usage_count, presence: true, numericality: { greater_than: 0 }

  # Scope for current month usage
  scope :this_month, -> { where('used_at >= ?', Time.current.beginning_of_month) }

  # Scope for specific feature type
  scope :for_feature, ->(feature_type) { where(feature_type: feature_type) }

  # Default values
  after_initialize :set_defaults, if: :new_record?

  private

  def set_defaults
    self.used_at ||= Time.current
    self.feature_type ||= 'ai_evidence'
    self.usage_count ||= 1
  end
end
