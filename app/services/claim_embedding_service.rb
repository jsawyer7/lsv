require 'openai'
require 'digest'

class ClaimEmbeddingService
  def initialize(claim_text)
    @claim_text = claim_text.to_s.strip
  end

  def generate_embedding
    return nil if @claim_text.blank?

    client = OpenAI::Client.new(
      access_token: openai_api_key,
      log_errors: true
    )

    response = client.embeddings(
      parameters: {
        model: "text-embedding-3-large",
        input: @claim_text
      }
    )

    response.dig("data", 0, "embedding")
  rescue => e
    Rails.logger.error "Failed to generate embedding: #{e.message}"
    nil
  end

  def normalize_content
    return "" if @claim_text.blank?

    # Strip whitespace, convert to lowercase, remove punctuation
    normalized = @claim_text.strip.downcase
    normalized = normalized.gsub(/[^\w\s]/, '') # Remove punctuation
    normalized = normalized.gsub(/\s+/, ' ') # Normalize whitespace
    normalized.strip
  end

  def generate_hash
    Digest::SHA256.hexdigest(normalize_content)
  end

  private

  def openai_api_key
    Rails.application.secrets.dig(:openai, :api_key)
  end
end
