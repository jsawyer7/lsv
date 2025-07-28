class AiDefinitionEvidenceService
  def initialize(claim_content)
    @claim_content = claim_content
  end

  def generate_definition_evidence(user_query = nil)
    prompt = build_prompt(user_query)

    begin
      response = openai_client.chat(
        parameters: {
          model: "gpt-4o",
          messages: [
            {
              role: "system",
              content: "You are an expert linguist and scholar specializing in religious and philosophical terminology. Provide precise definitions with etymological context and usage examples."
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
      Rails.logger.error "AI Definition Evidence Service error: #{e.message}"
      { error: "Failed to generate definition evidence: #{e.message}" }
    end
  end

  private

  def build_prompt(user_query)
    base_prompt = <<~PROMPT
      For the claim: "#{@claim_content}"

      Please provide definition evidence with the following structure:

      1. **Term/Concept**: The key term or concept being defined
      2. **Definition**: Precise definition with linguistic accuracy
      3. **Etymology**: Origin and historical development of the term
      4. **Usage Context**: How the term is used in religious or philosophical contexts

      Important guidelines:
      - Focus on precise, scholarly definitions
      - Include etymological information when relevant
      - Provide context about how the term is used in religious texts
      - Distinguish between literal and metaphorical meanings
      - Include examples of usage in relevant contexts
      - Consider cultural and historical variations in meaning

      #{user_query ? "User specific request: #{user_query}" : ""}

      Please format your response as JSON:
      {
        "term": "Key term or concept",
        "definition": "Precise definition",
        "etymology": "Origin and development",
        "usage_context": "How it's used in context"
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
        {
          term: parsed["term"],
          definition: parsed["definition"],
          etymology: parsed["etymology"],
          usage_context: parsed["usage_context"],
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

    term = lines.find { |line| line.match?(/term|concept|word/i) } || "Term/Concept"
    definition = lines.find { |line| line.match?(/definition|meaning/i) } || "Definition"
    etymology = lines.find { |line| line.match?(/etymology|origin|root/i) } || "Etymology"
    usage = lines.find { |line| line.match?(/usage|context|how/i) } || "Usage Context"

    {
      term: term,
      definition: definition,
      etymology: etymology,
      usage_context: usage,
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
