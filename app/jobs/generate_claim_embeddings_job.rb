class GenerateClaimEmbeddingsJob < ApplicationJob
  queue_as :default

  def perform(claim_id = nil)
    if claim_id
      # Generate embedding for a specific claim
      claim = Claim.find(claim_id)
      generate_embedding_for_claim(claim)
        else
      # Generate embeddings for all published facts without embeddings
      claims = Claim.where(content_embedding: nil, published: true, fact: true).where.not(content: [nil, ''])

      claims.find_each(batch_size: 10) do |claim|
        generate_embedding_for_claim(claim)
        sleep(0.1) # Rate limiting for OpenAI API
      end
    end
  end

  private

  def generate_embedding_for_claim(claim)
    return unless claim.content.present?
    return unless claim.fact? && claim.published?

    embedding_service = ClaimEmbeddingService.new(claim.content)
    embedding = embedding_service.generate_embedding
    normalized_hash = embedding_service.generate_hash

    if embedding.present? && normalized_hash.present?
      claim.update_columns(
        content_embedding: embedding,
        normalized_content_hash: normalized_hash
      )
      Rails.logger.info "Generated embedding for fact #{claim.id}"
    else
      Rails.logger.error "Failed to generate embedding for fact #{claim.id}"
    end
  rescue => e
    Rails.logger.error "Error generating embedding for fact #{claim.id}: #{e.message}"
  end
end
