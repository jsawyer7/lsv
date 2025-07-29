class AiLogicEvidenceService
  AVAILABLE_SOURCES = ['Quran', 'Tanakh', 'Catholic', 'Ethiopian', 'Protestant', 'Historical']

  def initialize(claim_content)
    @claim_content = claim_content
  end

  def generate_logic_evidence(user_query = nil)
    prompt = build_prompt(user_query)

    begin
      response = openai_client.chat(
        parameters: {
          model: "gpt-4o",
          messages: [
            {
              role: "system",
              content: "You are an expert in logical reasoning and philosophical argumentation. Provide clear, structured logical evidence with premises, conclusions, and reasoning. You must identify ALL relevant sources for the logical evidence from the available sources: #{AVAILABLE_SOURCES.join(', ')}."
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
      Rails.logger.error "AI Logic Evidence Service error: #{e.message}"
      { error: "Failed to generate logic evidence: #{e.message}" }
    end
  end

  private

  def build_prompt(user_query)
    base_prompt = <<~PROMPT
      For the claim: "#{@claim_content}"

      Please provide logical evidence with the following structure:

      1. **Premise**: The foundational statement or assumption
      2. **Sources**: Identify ALL relevant sources from these available options: #{AVAILABLE_SOURCES.join(', ')}
      3. **Reasoning**: The logical steps connecting the premise to the conclusion
      4. **Conclusion**: The logical conclusion that supports the claim
      5. **Logical Form**: The type of logical argument (deductive, inductive, etc.)

      Important guidelines:
      - Use clear, structured logical reasoning
      - Identify the type of logical argument being used
      - Ensure premises are well-founded and relevant
      - Show clear connections between premises and conclusions
      - Avoid logical fallacies
      - Consider alternative viewpoints and counterarguments
      - Use formal logical structures when appropriate
      - **CRITICAL**: Identify ALL relevant sources for the logical evidence:
        * Religious logical arguments → Sources: [relevant religious sources] (e.g., ["Quran"], ["Catholic"])
        * Philosophical logical arguments → Sources: ["Historical"] + relevant religious sources
        * Cross-cultural logical arguments → Sources: [all relevant religious sources]
        * Historical logical arguments → Sources: ["Historical"]

      #{user_query ? "User specific request: #{user_query}" : ""}

      Please format your response as JSON:
      {
        "premise": "Foundational statement or assumption",
        "sources": ["Historical", "Catholic"],
        "reasoning": "Logical steps and connections",
        "conclusion": "Logical conclusion",
        "logical_form": "Type of logical argument"
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
          premise: parsed["premise"],
          sources: sources,
          reasoning: parsed["reasoning"],
          conclusion: parsed["conclusion"],
          logical_form: parsed["logical_form"],
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

    premise = lines.find { |line| line.match?(/premise|assumption|foundation/i) } || "Premise"
    sources = ["Historical"] # Default to Historical for logic evidence
    reasoning = lines.find { |line| line.match?(/reasoning|logic|steps/i) } || "Reasoning"
    conclusion = lines.find { |line| line.match?(/conclusion|therefore|thus/i) } || "Conclusion"
    logical_form = lines.find { |line| line.match?(/logical|form|type/i) } || "Logical Form"

    {
      premise: premise,
      sources: sources,
      reasoning: reasoning,
      conclusion: conclusion,
      logical_form: logical_form,
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
