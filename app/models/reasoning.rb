class Reasoning < ApplicationRecord
  belongs_to :reasonable, polymorphic: true

  SOURCES = %w[Quran Tanakh Catholic Ethiopian Protestant Historical].freeze

  validates :source, presence: true, inclusion: { in: SOURCES }
  validates :response, presence: true
  validates :reasonable_id, uniqueness: { scope: [:reasonable_type, :source] }

  # Name normalization methods
  def self.name_normalization_service
    @name_normalization_service ||= NameNormalizationService.new
  end

  # Get response with names normalized for a specific tradition
  def response_for_tradition(tradition = 'actual')
    if normalized_content.present?
      self.class.name_normalization_service.denormalize_text(normalized_content, tradition)
    else
      response
    end
  end

  # Normalize content and save
  def normalize_and_save_content!
    return unless response.present?
    
    normalized = self.class.name_normalization_service.normalize_text(response)
    update_column(:normalized_content, normalized) if normalized != response
  end

  # Check if response contains mapped names
  def contains_mapped_names?
    return false if response.blank?
    self.class.name_normalization_service.contains_mapped_names?(response)
  end

  # Get all internal IDs used in this reasoning
  def internal_ids_used
    return [] unless normalized_content.present?
    self.class.name_normalization_service.extract_internal_ids(normalized_content)
  end
end 