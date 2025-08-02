require 'neighbor'

class DuplicateClaimDetectorService
  SIMILARITY_THRESHOLD = 0.9
  POSSIBLE_MATCH_THRESHOLD = 0.75
  MAX_SIMILAR_CLAIMS = 20

  def initialize(claim_text, evidence_texts = [], current_claim = nil)
    @claim_text = claim_text.to_s.strip
    @evidence_texts = Array(evidence_texts).compact
    @current_claim = current_claim
    @embedding_service = ClaimEmbeddingService.new(@claim_text)
    @name_normalization_service = NameNormalizationService.new
  end

  def detect_duplicates
    return empty_result if @claim_text.blank?

    # 1. Exact match check (using normalized content)
    exact_matches = find_exact_matches

    # 2. Semantic similarity check
    semantic_matches = find_semantic_matches

    # 3. Name-normalized exact match check
    normalized_exact_matches = find_normalized_exact_matches

    {
      exact_matches: serialize_claims(exact_matches),
      strong_matches: semantic_matches[:strong],
      possible_matches: semantic_matches[:possible],
      normalized_exact_matches: serialize_claims(normalized_exact_matches),
      has_duplicates: exact_matches.any? || semantic_matches[:strong].any? || semantic_matches[:possible].any? || normalized_exact_matches.any?
    }
  end

  private

  def empty_result
    {
      exact_matches: [],
      strong_matches: [],
      possible_matches: [],
      normalized_exact_matches: [],
      has_duplicates: false
    }
  end

  def find_exact_matches
    normalized_hash = @embedding_service.generate_hash
    return [] if normalized_hash.blank?

    claims = Claim.where(normalized_content_hash: normalized_hash, published: true)
    claims = claims.where.not(id: @current_claim.id) if @current_claim
    claims.includes(:user, :evidences).limit(10)
  end

  def find_normalized_exact_matches
    # Normalize the current claim text
    normalized_text = @name_normalization_service.normalize_text(@claim_text)
    normalized_hash = Digest::SHA256.hexdigest(normalized_text.downcase.strip)
    
    return [] if normalized_hash.blank?

    # Find claims with the same normalized content
    claims = Claim.where(normalized_content_hash: normalized_hash, published: true)
    claims = claims.where.not(id: @current_claim.id) if @current_claim
    claims.includes(:user, :evidences).limit(10)
  end

  def find_semantic_matches
    embedding = @embedding_service.generate_embedding
    return { strong: [], possible: [] } if embedding.blank?

    # Use PostgreSQL vector similarity search - only for published facts
    similar_claims = Claim.where.not(content_embedding: nil, published: true)
    similar_claims = similar_claims.where.not(id: @current_claim.id) if @current_claim
    similar_claims = similar_claims.order(Arel.sql("content_embedding <=> '#{embedding.to_json}'::vector"))
                                 .limit(MAX_SIMILAR_CLAIMS)
                                 .includes(:user, :evidences)

    strong_matches = []
    possible_matches = []

    similar_claims.each do |claim|
      next unless claim.content_embedding.present?

      similarity = calculate_cosine_similarity(embedding, claim.content_embedding)

      if similarity >= SIMILARITY_THRESHOLD
        strong_matches << {
          claim: serialize_claim(claim),
          similarity: similarity.round(3),
          similarity_percentage: (similarity * 100).round(1)
        }
      elsif similarity >= POSSIBLE_MATCH_THRESHOLD
        possible_matches << {
          claim: serialize_claim(claim),
          similarity: similarity.round(3),
          similarity_percentage: (similarity * 100).round(1)
        }
      end
    end

    { strong: strong_matches, possible: possible_matches }
  rescue => e
    Rails.logger.error "Semantic matching failed: #{e.message}"
    { strong: [], possible: [] }
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

  def serialize_claims(claims)
    claims.map { |claim| serialize_claim(claim) }
  end

  def serialize_claim(claim)
    {
      id: claim.id,
      content: claim.content,
      created_at: claim.created_at,
      user: {
        full_name: claim.user&.full_name,
        email: claim.user&.email
      },
      evidences: claim.evidences.map do |evidence|
        {
          id: evidence.id,
          content: evidence.content,
          source_names: evidence.source_names
        }
      end
    }
  end
end
