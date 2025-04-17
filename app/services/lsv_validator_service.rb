require 'openai'
require 'json'

class LsvValidatorService
  def initialize(claim)
    @claim = claim
  end

  def run_validation!
    response = send_to_openai(@claim)
    json = parse_response_json(response)

    {
      badge: parse_badge(json),
      reasoning: parse_reasoning(response)
    }
  rescue => e
    Rails.logger.error "OpenAI Error: #{e.message}"
    {
      badge: "❌ Validation failed",
      reasoning: "An error occurred while validating the claim."
    }
  end

  private

  def lsv_prompt(claim)
    <<~PROMPT
      You are validating claims using the Literal Source Verification (LSV) method. Use the following rules:
      - LSV permits claims based on literal text from one or more of the Tanakh, Christian Bibles, or Quran.
      - A claim is valid if it is explicitly supported by at least one of these sources and not contradicted by any others.
      - Verifiable historical facts and pure logic may validate a claim, as long as no scripture contradicts it.
      - Textual silence in one or more books does not invalidate the claim if there is no contradiction.
      - Claims may be limited in scope (e.g., "The Tanakh says...") and only need support within that scope.
      - Reject ambiguous or open-ended claims using "may," "could," or "possibly."
      - Do not use theology, doctrine, scholarly opinion, or interpretation.
      - Evaluate only the literal text, history, and logic within the defined scope of the claim.
      Here is the fact to evaluate:
      "#{claim.content}"
      If available, also consider the following evidence provided by the user:
      "#{claim.evidence}"
      Is this fact 100% accurate under the LSV guidelines?

      Respond strictly in valid JSON format:

      {
        "valid": true or false,
        "reasoning": "Your reasoning for whether this claim meets the LSV standard.",
        "flag": "none" | "rejected" | "evidence weak"
      }

      Do not include anything outside this JSON block.
    PROMPT
  end

  def send_to_openai(claim)
    client = OpenAI::Client.new(
      access_token: openai_api_key,
      organization_id: openai_organization_id,
      log_errors: true
    )

    prompt = lsv_prompt(claim)

    client.chat(
      parameters: {
        model: "gpt-4o",
        messages: [{ role: "user", content: prompt }],
        temperature: 0.0
      }
    )
  end

  def parse_response_json(response)
    raw_message = response.dig("choices", 0, "message", "content") || ""

    json_str = raw_message.gsub(/```json|```/, '').strip

    JSON.parse(json_str)
  rescue JSON::ParserError => e
    Rails.logger.error "Failed to parse OpenAI response JSON: #{e.message}"
    {
      "valid" => false,
      "reasoning" => "The response was not in valid JSON format.",
      "flag" => "rejected"
    }
  end

  def parse_badge(response)
    case response["valid"]
    when true
      "✅ True"
    when false
      if response["flag"] == "evidence weak"
        "⚠️ Unverifiable"
      else
        "❌ False"
      end
    else
      "⚠️ Unknown"
    end
  end

  def parse_reasoning(response)
    result = parse_response_json(response)
    result["reasoning"] || "No reasoning provided."
  end


  def openai_api_key
    Rails.application.secrets.dig(:openai, :api_key)
  end

  def openai_organization_id
    Rails.application.secrets.dig(:openai, :organization_id)
  end
end
