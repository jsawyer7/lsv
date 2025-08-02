class Claim < ApplicationRecord
  belongs_to :user
  has_many :challenges, dependent: :destroy
  has_many :reasonings, as: :reasonable, dependent: :destroy
  has_many :evidences, dependent: :destroy

  validates :content, presence: true

  # Embedding generation will be handled in the publish action

  enum state: {
    draft: 'draft',
    ai_validated: 'ai_validated',
    verified: 'verified'
  }, _default: 'draft'

  scope :drafts, -> { where(state: 'draft') }
  scope :ai_validated, -> { where(state: 'ai_validated') }
  scope :verified, -> { where(state: 'verified') }
  scope :published_facts, -> { where(fact: true, published: true) }
  scope :facts, -> { where(fact: true) }
  scope :with_embeddings, -> { where.not(content_embedding: nil) }
  scope :published_facts_without_embeddings, -> { where(published: true, fact: true, content_embedding: nil).where.not(content: [nil, '']) }

  # Name normalization service
  def self.name_normalization_service
    @name_normalization_service ||= NameNormalizationService.new
  end

  def reasoning_for(source)
    reasonings.find_by(source: source)&.response
  end

  # Get content with names normalized for a specific tradition
  def content_for_tradition(tradition = 'actual')
    if normalized_content.present?
      self.class.name_normalization_service.denormalize_text(normalized_content, tradition)
    else
      content
    end
  end

  # Get all evidence content with names normalized for a specific tradition
  def evidence_content_for_tradition(tradition = 'actual')
    evidences.map do |evidence|
      if evidence.normalized_content.present?
        self.class.name_normalization_service.denormalize_text(evidence.normalized_content, tradition)
      else
        evidence.evidence_content
      end
    end.join("\n\n")
  end

  # Get all reasoning content with names normalized for a specific tradition
  def reasoning_content_for_tradition(tradition = 'actual')
    reasonings.map do |reasoning|
      if reasoning.normalized_content.present?
        self.class.name_normalization_service.denormalize_text(reasoning.normalized_content, tradition)
      else
        reasoning.response
      end
    end.join("\n\n")
  end

  # Normalize content and save
  def normalize_and_save_content!
    return unless content.present?
    
    normalized = self.class.name_normalization_service.normalize_text(content)
    update_column(:normalized_content, normalized) if normalized != content
  end

  # Check if content contains mapped names
  def contains_mapped_names?
    self.class.name_normalization_service.contains_mapped_names?(content)
  end

  # Get all internal IDs used in this claim
  def internal_ids_used
    return [] unless normalized_content.present?
    self.class.name_normalization_service.extract_internal_ids(normalized_content)
  end

  # Define ransackable attributes
  def self.ransackable_attributes(auth_object = nil)
    %w[
      id
      content
      normalized_content
      created_at
      updated_at
      user_id
    ]
  end

  # Define ransackable associations
  def self.ransackable_associations(auth_object = nil)
    %w[user reasonings evidences]
  end

  private

    def generate_embedding
    return unless content.present?

    embedding_service = ClaimEmbeddingService.new(content)
    embedding = embedding_service.generate_embedding
    normalized_hash = embedding_service.generate_hash

    if embedding.present? && normalized_hash.present?
      update_columns(
        content_embedding: embedding,
        normalized_content_hash: normalized_hash
      )
    end
  rescue => e
    Rails.logger.error "Failed to generate embedding for claim #{id}: #{e.message}"
  end
end
