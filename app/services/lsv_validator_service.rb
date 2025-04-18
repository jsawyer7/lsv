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
      You are an AI trained to validate religious claims using the Literal Source Verification (LSV) method only. You must follow these exact rules:
      🔒 VALIDATION PROTOCOL:
      - Accept literal statements from the Tanakh (Hebrew Bible), any Christian Bible (e.g., Protestant, Catholic, Orthodox, Ethiopian), and the Quran (in Arabic or reliable English translation).
      - Do not reject claims based on canonical differences. If a source is explicitly part of any recognized canon (e.g., 1 Enoch in the Ethiopian Bible), it qualifies for LSV validation.
      - Accept verified historical facts (e.g., Josephus, Tacitus) and pure logic as evidence—if not contradicted by scripture.
      - Exclude theology, doctrine, tradition, mystical interpretation, and commentaries—even if widely accepted.
      - If the claim explicitly identifies its scope (e.g., “historically,” “per the Tanakh”), only evaluate within that scope.
      - Do not penalize the claim if other sources are silent, unless one contradicts it directly.

      🎯 VERDICT RULE:
      Only label a claim "False" if it clearly violates a literal verse, a historical fact, or logical contradiction. Otherwise, validate it as "True."
      Now, using the LSV criteria above, evaluate the following claim and evidence:
      ---
      Claim:
      "#{claim.content}"
      Evidence:
      "#{claim.evidence}"
      ---
      Is the claim True or False according to LSV rules? Give a one-sentence reason.

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
        messages: [{ role: "system", content: prompt }],
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
