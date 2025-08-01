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

  def reasoning_for(source)
    reasonings.find_by(source: source)&.response
  end

  # Define ransackable attributes
  def self.ransackable_attributes(auth_object = nil)
    %w[
      id
      content
      state
      fact
      published
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
