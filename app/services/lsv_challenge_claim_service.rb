class LsvChallengeClaimService
  def initialize(challenge)
    @challenge = challenge
    @claim = challenge.claim
  end

  def process
    @challenge.update(status: 'processing')
    
    begin
      response = validate_challenge
      @challenge.update(
        ai_response: response,
        status: 'completed'
      )
    rescue => e
      Rails.logger.error("Challenge validation failed: #{e.message}")
      @challenge.update(
        ai_response: "Error processing challenge: #{e.message}",
        status: 'failed'
      )
    end
  end

  private

  def validate_challenge
    client = OpenAI::Client.new(
      access_token: openai_api_key,
      organization_id: openai_organization_id,
      log_errors: true
    )
    
    prompt = generate_prompt
    
    response = client.chat(
      parameters: {
        model: "gpt-4o",
        messages: [{ role: "system", content: prompt }],
        temperature: 0.0
      }
    )

    response.dig("choices", 0, "message", "content")
  end

  def generate_prompt
    <<~PROMPT
      You are an AI LSV (Literal Source Verification) validator analyzing a challenge to a claim.
      
      Original Claim:
      #{@claim.content}
      
      Original Evidence:
      #{@claim.evidence}
      
      Challenge Text:
      #{@challenge.text}
      
      Please analyze this challenge considering:
      1. The validity of the challenge against the original claim
      2. How well the challenge addresses the evidence provided
      3. Whether the challenge brings new perspectives or evidence
      4. The logical consistency of the challenge
      
      Provide a detailed analysis in the following format:
      
      Challenge Analysis:
      [Your detailed analysis of the challenge]
      
      Validity Score (1-10):
      [Score with brief explanation]
      
      Recommendation:
      [Whether the challenge should be considered valid and why]
      
      Additional Notes:
      [Any other relevant observations]
    PROMPT
  end

  def openai_api_key
    Rails.application.secrets.dig(:openai, :api_key)
  end

  def openai_organization_id
    Rails.application.secrets.dig(:openai, :organization_id)
  end
end 