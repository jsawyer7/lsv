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
      Your task is to inspect the user-supplied evidence list and decide which of the
      #{AVAILABLE_SOURCES.join(", ")} are directly referenced.

      Definitions
      -----------
      • "Referenced" means the evidence explicitly cites a book / chapter / verse
        (e.g. "John 1:1") **or** cites a recognisable non-canonical historical source
        (e.g. an ancient historian, inscription, manuscript, archaeological find).

      • A "canonical source" is one of the scriptural canons in
        #{AVAILABLE_SOURCES.join(", ")}

      • **Historical** is a catch-all label:  
        - Mark "Historical" **primary** if the evidence references **any** source
          that is **not** one of the scriptural canons listed in AVAILABLE_SOURCES  
          (e.g. Josephus, Tacitus, Dead Sea Scrolls, an ossuary, a stele inscription).

      • Do **not** infer meaning or theological support.  
        Only decide whether each evidence item belongs inside a source's canon.

      Instructions
      ------------
      1. Examine every evidence reference.  
      2. For each reference, add every canon it appears in to **primary_sources**.  
      3. If a reference is not found in any listed canon, add **Historical**
        to **primary_sources** (once only, no duplications).  
      4. All other sources become **secondary_sources**.
      5. For each evidence item, determine its primary source and include it in the **evidences** array.
         - The `evidence` field must contain the full formatted evidence string, e.g.:
           "Reference: John 1:1, Original: , Translation: "
         - If Original or Translation are not available, leave them blank but include the labels.

      Evidence Provided:
      #{@evidence.join("\n\n")}

      Available sources: #{AVAILABLE_SOURCES.join(", ")}

      Respond in pure JSON:

      {
        "primary_sources": ["..."],
        "secondary_sources": ["..."],
        "evidences": [
          {"evidence": "Reference: John 1:1, Original: , Translation: ", "source": "Protestant"},
          {"evidence": "Reference: Surah 4:157, Original: , Translation: ", "source": "Quran"},
          {"evidence": "Reference: Tacitus Annals 15.44, Original: , Translation: ", "source": "Historical"}
        ]
      }
    PROMPT
  end

  def user_prompt
    "Please analyze this evidence and categorize the sources:\n\n#{@evidence.join("\n\n")}"
  end
end 