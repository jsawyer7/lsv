class TextTranslation < ApplicationRecord
  belongs_to :text_content
  belongs_to :language_target, class_name: 'Language'

  validates :text_content, presence: true
  validates :language_target, presence: true
  validates :ai_translation, presence: true
  validates :ai_explanation, presence: true
  validates :revision_number, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :ai_confidence_score, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }, allow_nil: true
  validates :text_content_id, uniqueness: { scope: :revision_number }

  scope :latest, -> { where(is_latest: true) }
  scope :for_content, ->(id) { where(text_content_id: id) }

  def self.ransackable_attributes(auth_object = nil)
    [
      "ai_confidence_score", "ai_model_name", "ai_translation", "ai_explanation", "created_at",
      "id", "is_latest", "language_target_id", "notes", "revision_number", "text_content_id",
      "updated_at", "confirmed_at", "confirmed_by", "summary_and_differences"
    ]
  end

  def self.ransackable_associations(auth_object = nil)
    ["language_target", "text_content"]
  end
end


