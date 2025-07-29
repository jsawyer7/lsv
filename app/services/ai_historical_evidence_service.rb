class AiHistoricalEvidenceService
  AVAILABLE_SOURCES = ['Quran', 'Tanakh', 'Catholic', 'Ethiopian', 'Protestant', 'Historical']

  def initialize(claim_content)
    @claim_content = claim_content
  end

  def generate_historical_evidence(user_query = nil)
    prompt = build_prompt(user_query)

    begin
      response = openai_client.chat(
        parameters: {
          model: "gpt-4o",
          messages: [
            {
              role: "system",
              content: "You are an expert historian specializing in religious and cultural history. Provide accurate, well-documented historical evidence with proper citations and context. You must identify ALL relevant sources for the historical evidence from the available sources: #{AVAILABLE_SOURCES.join(', ')}."
            },
            {
              role: "user",
              content: prompt
            }
          ],
          temperature: 0.3,
          max_tokens: 1000
        }
      )

      parse_response(response.dig("choices", 0, "message", "content"))
    rescue => e
      Rails.logger.error "AI Historical Evidence Service error: #{e.message}"
      { error: "Failed to generate historical evidence: #{e.message}" }
    end
  end

  private

  def build_prompt(user_query)
    base_prompt = <<~PROMPT
      For the claim: "#{@claim_content}"

      Please provide historical evidence with the following structure:

      1. **Historical Event/Period**: The specific historical event, period, or context
      2. **Sources**: Identify ALL relevant sources from these available options: #{AVAILABLE_SOURCES.join(', ')}
      3. **Description**: Detailed description of the historical evidence
      4. **Relevance**: How this historical evidence supports or relates to the claim

      Important guidelines:
      - Focus on verifiable historical facts and documented events
      - Include specific dates, locations, and historical figures when relevant
      - Cite reliable historical sources and documents
      - Provide context about the historical period and cultural background
      - Ensure the evidence directly relates to or supports the claim
      - Distinguish between primary and secondary sources
      - **CRITICAL**: Identify ALL relevant sources for the historical evidence:
        * Religious historical events → Sources: ["Historical"] + relevant religious source (e.g., ["Historical", "Catholic"])
        * Archaeological findings → Sources: ["Historical"]
        * Historical documents from specific traditions → Sources: ["Historical"] + specific tradition (e.g., ["Historical", "Ethiopian"])
        * Cross-cultural historical events → Sources: ["Historical"] + all relevant religious sources

      #{user_query ? "User specific request: #{user_query}" : ""}

      Please format your response as JSON:
      {
        "historical_event": "Specific historical event or period",
        "sources": ["Historical", "Catholic"],
        "description": "Detailed description of the historical evidence",
        "relevance": "How this evidence supports the claim"
      }
    PROMPT

    base_prompt
  end

  def parse_response(content)
    begin
      # Try to extract JSON from the response
      json_match = content.match(/\{[\s\S]*\}/)
      if json_match
        parsed = JSON.parse(json_match[0])
        sources = parsed["sources"] || [parsed["source"]].compact

        # If sources is still empty, default to Historical
        if sources.empty?
          sources = ["Historical"]
        end

        {
          historical_event: parsed["historical_event"],
          sources: sources,
          description: parsed["description"],
          relevance: parsed["relevance"],
          success: true
        }
      else
        # Fallback: parse the text manually
        parse_text_response(content)
      end
    rescue JSON::ParserError => e
      Rails.logger.error "Failed to parse AI response as JSON: #{e.message}"
      parse_text_response(content)
    end
  end

  def parse_text_response(content)
    # Fallback parsing for non-JSON responses
    lines = content.split("\n").map(&:strip).reject(&:empty?)

    event = lines.find { |line| line.match?(/event|period|history/i) } || "Historical Event"
    sources = ["Historical"] # Default to Historical for historical evidence
    description = lines.find { |line| line.match?(/description|detail/i) } || "Description"
    relevance = lines.find { |line| line.match?(/relevance|support|relate/i) } || "Relevance"

    {
      historical_event: event,
      sources: sources,
      description: description,
      relevance: relevance,
      success: true
    }
  end

  def openai_client
    @openai_client ||= OpenAI::Client.new(access_token: openai_api_key)
  end

  def openai_api_key
    Rails.application.secrets.dig(:openai, :api_key)
  end
end
