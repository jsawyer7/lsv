class LsvEvidenceValidatorService
  AVAILABLE_SOURCES = ['Quran', 'Tanakh', 'Catholic', 'Ethiopian', 'Protestant', 'Historical']

  class ValidationError < StandardError; end

  def initialize(evidence, sources)
    @evidence = evidence.to_s
    @sources = Array(sources)
    
    validate_inputs!
  end

  def analyze_sources!
    raise ValidationError, "Evidence text is required" if @evidence.blank?
    raise ValidationError, "At least one source must be selected" if @sources.empty?

    response = client.chat(
      parameters: {
        model: "gpt-4-turbo-preview",
        messages: [
          { role: "system", content: system_prompt },
          { role: "user", content: user_prompt }
        ],
        temperature: 0.7,
        response_format: { type: "json_object" }
      }
    )

    result = JSON.parse(response.dig("choices", 0, "message", "content"))
    
    {
      primary_sources: result["primary_sources"],
      secondary_sources: result["secondary_sources"]
    }
  rescue OpenAI::Error => e
    Rails.logger.error("OpenAI API Error: #{e.message}")
    raise ValidationError, "Failed to analyze evidence. Please try again."
  rescue JSON::ParserError => e
    Rails.logger.error("JSON Parse Error: #{e.message}")
    raise ValidationError, "Failed to process the analysis results. Please try again."
  end

  private

  def openai_api_key
    Rails.application.secrets.dig(:openai, :api_key)
  end

  def openai_organization_id
    Rails.application.secrets.dig(:openai, :organization_id)
  end

  def validate_inputs!
    raise ValidationError, "Evidence text is required" if @evidence.blank?
    raise ValidationError, "At least one source must be selected" if @sources.empty?
    
    invalid_sources = @sources - AVAILABLE_SOURCES
    if invalid_sources.any?
      raise ValidationError, "Invalid sources selected: #{invalid_sources.join(', ')}"
    end
  end

  def client
    @client ||= OpenAI::Client.new(
      access_token: openai_api_key,
      organization_id: openai_organization_id,
      log_errors: true
    )
  end

  def system_prompt
    <<~PROMPT
      You are an expert in analyzing religious and historical texts. Your task is to analyze the given evidence 
      and determine which sources from the provided list are directly referenced or quoted in the evidence.
      
      Available sources: #{AVAILABLE_SOURCES.join(", ")}
      
      Respond in JSON format with two arrays:
      1. primary_sources: Sources that are directly quoted or referenced in the evidence
      2. secondary_sources: Sources from the list that are not directly referenced
      
      Example response format:
      {
        "primary_sources": ["Quran", "Tanakh"],
        "secondary_sources": ["Catholic", "Ethiopian", "Protestant", "Historical"]
      }
    PROMPT
  end

  def user_prompt
    "Please analyze this evidence and categorize the sources:\n\n#{@evidence}"
  end
end 