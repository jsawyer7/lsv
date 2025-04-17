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
      Literal Source Verification (LSV)
      Definition: Literal Source Verification (LSV) is a cross-scriptural method for identifying indisputable religious facts using only the literal text of the following primary sources:
      Tanakh (Hebrew Bible)
      Christian Bibles (any canon/version, e.g., Protestant, Catholic, Ethiopian Orthodox)
      Quran (original Arabic text, cross-validated with English translations for clarity)
      Additionally, the method incorporates:
      Verifiable historical evidence, including manuscript evidence and archaeological findings.
      Pure logic, devoid of inherited theological or doctrinal biases.
      Exclusions: The following are explicitly excluded from the LSV method:
      Theology
      Religious doctrine
      Church/mosque/synagogue council decisions
      Religious commentaries
      Mystical writings
      Inherited religious interpretations
      Guidelines:
      The Tanakh is treated independently in its original Hebrew, separate from Christian Old Testament arrangements.
      Any recognized biblical canon (Protestant, Catholic, Orthodox, Ethiopian, etc.) is permitted.
      The Quran must be referenced in its original Arabic with linguistically accurate English translations.
      LSV focuses strictly on what the texts literally say, without influence from tradition or theology.
      Additional Rules for Clarity and Precision:
      Claims Must Be Definitive:
      Ambiguous or open-ended claims using words like "possible," "could," "might," or "may" are not permitted.
      Every claim must clearly state explicit factual assertions or explicit denials to ensure they are testable and verifiable.
      Explicit Scope and Evidence Flexibility:
      Claims may limit their scope to a single source (e.g., "The Tanakh explicitly states...") as long as this is clearly stated.
      Generalized claims across multiple scriptures do not require explicit affirmation from each source. A claim may be validated if:
      It is explicitly supported in one or more scriptures, and not contradicted in the others;
      It is supported by historical fact or pure logic, provided no scripture directly contradicts it.
      Silence in other sources does not disqualify a valid claim if no contradiction exists.
      Peer-Level Human Validation Layer:
      To ensure the integrity of claims and catch potential oversights by the user or AI, each claim should be subject to human peer validation using the same LSV criteria.
      Any challenge to a claim must also follow LSV standards—relying solely on literal text, historical facts, or logic within the stated scope.
      This process ensures all claims are tested against both textual evidence and critical review, reinforcing reliability.
      Logical Inference of Intent from Pattern and Capability:
      LSV permits factual claims about God's intent or purpose when:
      They are logically derived from God's capabilities, known actions, and consistent scriptural patterns;
      They are supported by historical facts or scriptural examples (e.g., God writing with His finger, choosing intermediaries);
      And no scripture directly contradicts the inferred conclusion.
      The absence of an explicit statement of intent does not disqualify a claim if the reasoning is sound and the evidence is literal.
      Purpose: LSV is designed for rigorous analysis by scholars, theologians, truth-seekers, interfaith researchers, and anyone seeking to verify religious claims independently from inherited doctrines, biases, or external theological frameworks.

      Important: A claim does not require all relevant texts to explicitly state a conclusion, if it is supported by historical fact or logic and no contradiction exists in the text.
      Do not reject a claim simply because God's “intent” or outcome is inferred rather than directly quoted.
      Inference is valid under LSV if it logically follows from God's demonstrated capability (e.g., writing directly), consistent patterns, and historical actions—and no text contradicts it.
      “Speculation” only occurs when the claim cannot be supported by any text, logic, or historical fact, or is contradicted.
      Here is the claim to evaluate:
      "#{claim.content}"
      If available, also consider the following evidence provided by the user:
      "#{claim.evidence}"
      Is this claim 100% accurate under the LSV guidelines?

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
