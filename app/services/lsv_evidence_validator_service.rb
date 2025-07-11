class LsvEvidenceValidatorService
  AVAILABLE_SOURCES = ['Quran', 'Tanakh', 'Catholic', 'Ethiopian', 'Protestant', 'Historical']

  class ValidationError < StandardError; end

  def initialize(evidence, sources)
    @evidence = evidence.is_a?(Array) ? evidence : [evidence.to_s]
    @sources = Array(sources)
    
    validate_inputs!
  end

  def analyze_sources!
    raise ValidationError, "Evidence text is required" if @evidence.empty? || @evidence.all?(&:blank?)
    raise ValidationError, "At least one source must be selected" if @sources.empty?

    response = client.chat(
      parameters: {
        model: "gpt-4-turbo-preview",
        messages: [
          { role: "system", content: system_prompt },
          { role: "user", content: user_prompt }
        ],
        temperature: 0.0,
        response_format: { type: "json_object" }
      }
    )

    begin
      result = JSON.parse(response.dig("choices", 0, "message", "content"))
      {
        primary_sources: result["primary_sources"] || [],
        secondary_sources: result["secondary_sources"] || [],
        evidences: result["evidences"] || [],
        warning: nil
      }
    rescue JSON::ParserError => e
      Rails.logger.error("JSON Parse Error: #{e.message}")
      {
        primary_sources: [],
        secondary_sources: [],
        evidences: [],
        warning: "The AI service is down. Please try again in a while"
      }
    end
  rescue OpenAI::Error => e
    Rails.logger.error("OpenAI API Error: #{e.message}")
    raise ValidationError, "Failed to analyze evidence. Please try again."
  end

  private

  def openai_api_key
    Rails.application.secrets.dig(:openai, :api_key)
  end

  def openai_organization_id
    Rails.application.secrets.dig(:openai, :organization_id)
  end

  def validate_inputs!
    raise ValidationError, "Evidence text is required" if @evidence.empty? || @evidence.all?(&:blank?)
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
      You are an expert in analysing religious and historical texts.
      You will receive an array of evidence items. Each item in the array is a separate evidence box from the user.
      For each evidence item, determine ALL applicable sources (from: #{AVAILABLE_SOURCES.join(", ")}).
      DO NOT split or merge evidence items. If a single evidence item contains references to multiple sources, return it as a single evidence object with all applicable sources in the `sources` array.
      Only return as many evidence objects as you received in the input array, and in the same order.

      For each evidence item:
        - The `evidence` field must contain the EXACT ORIGINAL evidence text as provided by the user.
        - The `sources` field should contain an array of ALL applicable sources for this evidence.
        - DO NOT modify, format, or change the evidence text in any way.

      For the overall response:
        - `primary_sources`: The union of all sources referenced by any evidence item (no duplicates).
        - `secondary_sources`: All other sources from the available list that are NOT referenced by any evidence item.

      Respond in pure JSON:
      {
        "primary_sources": [...],
        "secondary_sources": [...],
        "evidences": [
          {"evidence": "EXACT ORIGINAL EVIDENCE TEXT", "sources": ["Source1", "Source2"]},
          ...
        ]
      }
    PROMPT
  end

  def user_prompt
    "Please analyze each evidence item in the array separately. Do not split or merge them. If a single evidence item contains references to multiple sources, return it as a single evidence object with all applicable sources. Return the sources for each evidence item in the same order as received. Evidence array:\n\n#{@evidence.to_json}"
  end
end 