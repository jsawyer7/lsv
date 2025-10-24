class Claim < ApplicationRecord
  belongs_to :user
  has_many :challenges, dependent: :destroy
  has_many :reasonings, as: :reasonable, dependent: :destroy
  has_many :evidences, dependent: :destroy

  validates :content, presence: true

  # Clean content before saving
  before_save :clean_content

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

  # Custom setter for primary_sources to handle comma-separated input
  def primary_sources_text=(text)
    if text.present?
      self.primary_sources = text.split(',').map(&:strip).reject(&:blank?)
    else
      self.primary_sources = []
    end
  end

  # Custom getter for primary_sources to return comma-separated text
  def primary_sources_text
    primary_sources&.join(', ')
  end

  # Custom setter for secondary_sources to handle comma-separated input
  def secondary_sources_text=(text)
    if text.present?
      self.secondary_sources = text.split(',').map(&:strip).reject(&:blank?)
    else
      self.secondary_sources = []
    end
  end

  # Custom getter for secondary_sources to return comma-separated text
  def secondary_sources_text
    secondary_sources&.join(', ')
  end

  # Generate hashes for all tradition variations
  def generate_tradition_hashes!
    return unless normalized_content.present?

    traditions = ['actual', 'jewish', 'christian', 'muslim', 'ethiopian']
    tradition_hashes = {}

    traditions.each do |tradition|
      # Denormalize content for this tradition
      denormalized_content = self.class.name_normalization_service.denormalize_text(normalized_content, tradition)

      # Generate hash for this tradition's content
      normalized_text = normalize_content_for_hash(denormalized_content)
      tradition_hashes[tradition] = Digest::SHA256.hexdigest(normalized_text)
    end

    # Store tradition hashes as JSON
    update_column(:tradition_hashes, tradition_hashes.to_json)
  end

  # Get tradition hashes
  def tradition_hashes
    return {} unless self[:tradition_hashes].present?

    begin
      JSON.parse(self[:tradition_hashes])
    rescue JSON::ParserError
      {}
    end
  end

  # Check for duplicates across all tradition variations
  def check_duplicates_across_traditions
    return [] unless normalized_content.present?

    all_hashes = tradition_hashes.values
    return [] if all_hashes.empty?

    # Find claims that have any of our tradition hashes
    Claim.where(published: true, fact: true)
         .where.not(id: id)
         .where("tradition_hashes IS NOT NULL")
         .select do |claim|
           claim_tradition_hashes = claim.tradition_hashes.values
           # Check if any of our hashes match any of their hashes
           (all_hashes & claim_tradition_hashes).any?
         end
  end

  # Enhanced duplicate detection that checks all tradition variations
  def detect_duplicates_with_traditions
    duplicates = []

    # Check exact matches for each tradition
    tradition_hashes.each do |tradition, hash|
      matching_claims = Claim.where(published: true, fact: true)
                            .where.not(id: id)
                            .where("tradition_hashes LIKE ?", "%\"#{tradition}\":\"#{hash}\"%")

      matching_claims.each do |claim|
        duplicates << {
          claim: claim,
          match_type: "exact_#{tradition}",
          tradition: tradition,
          similarity: 1.0
        }
      end
    end

    # Also check semantic similarity
    if content_embedding.present?
      similar_claims = Claim.where(published: true, fact: true)
                           .where.not(id: id)
                           .where.not(content_embedding: nil)
                           .order(Arel.sql("content_embedding <=> '#{content_embedding.to_json}'::vector"))
                           .limit(10)

      similar_claims.each do |claim|
        similarity = calculate_cosine_similarity(content_embedding, claim.content_embedding)
        if similarity >= 0.9
          duplicates << {
            claim: claim,
            match_type: "semantic",
            similarity: similarity
          }
        end
      end
    end

    duplicates.uniq { |d| d[:claim].id }
  end

  private

  def clean_content
    return unless content.present?
    # Remove trailing punctuation and special characters
    self.content = content.gsub(/[.!?;:,]+$/, '').strip
  end

  def normalize_content_for_hash(content)
    return "" if content.blank?

    # Strip whitespace, convert to lowercase, remove punctuation
    normalized = content.strip.downcase
    normalized = normalized.gsub(/[^\w\s]/, '') # Remove punctuation
    normalized = normalized.gsub(/\s+/, ' ') # Normalize whitespace
    normalized.strip
  end

  def calculate_cosine_similarity(embedding1, embedding2)
    return 0.0 if embedding1.blank? || embedding2.blank?

    # Ensure both are arrays
    vec1 = embedding1.is_a?(Array) ? embedding1 : embedding1.split(',').map(&:to_f)
    vec2 = embedding2.is_a?(Array) ? embedding2 : embedding2.split(',').map(&:to_f)

    return 0.0 if vec1.length != vec2.length

    # Calculate cosine similarity
    dot_product = 0.0
    magnitude1 = 0.0
    magnitude2 = 0.0

    vec1.each_with_index do |val1, i|
      val2 = vec2[i]
      dot_product += val1 * val2
      magnitude1 += val1 * val1
      magnitude2 += val2 * val2
    end

    magnitude1 = Math.sqrt(magnitude1)
    magnitude2 = Math.sqrt(magnitude2)

    return 0.0 if magnitude1.zero? || magnitude2.zero?

    dot_product / (magnitude1 * magnitude2)
  end

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
