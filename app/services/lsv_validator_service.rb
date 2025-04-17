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
      Confirm the below statement is 100% correct using the Literal Source Verification (LSV) method as outlined below.

      ======================
      Literal Source Verification (LSV) Framework

      Definition: Literal Source Verification (LSV) is a cross-scriptural method for identifying indisputable religious facts using only the literal text of the following primary sources:
      * Tanakh (Hebrew Bible)
      * Christian Bibles (any canon/version, e.g., Protestant, Catholic, Ethiopian Orthodox)
      * Quran (original Arabic text, cross-validated with English translations for clarity)
      Additionally, the method incorporates:
      * Verifiable historical evidence, including manuscript records and archaeological data
      * Pure logic, free from assumptions or doctrinal inferences



      Exclusions: The following are explicitly excluded from the LSV method:
      * Theology
      * Religious doctrine
      * Church/mosque/synagogue council decisions
      * Religious commentaries
      * Mystical writings
      * Inherited religious interpretations



      Core Guidelines
      * The Tanakh is treated independently in its original Hebrew, separate from Christian Old Testament arrangements.
      * Any recognized biblical canon (Protestant, Catholic, Orthodox, Ethiopian, etc.) is permitted.
      * The Quran must be referenced in its original Arabic, with validated English translations used for clarity and comparison.
      * LSV focuses strictly on what the texts literally say, uninfluenced by tradition, commentary, or theological speculation.



      Additional Rules for Clarity and Precision
      1. Claims Must Be Definitive
      * Claims must assert concrete truth statements.
      * Open-ended or ambiguous phrasing is not permitted. Phrases like "it's possible that…" or "some interpret…" are excluded.
      * Every claim must be testable and specific, either as an affirmative or as a falsifiable denial.



      2. Explicit Scope and Evidence Flexibility
      * Users may limit a claim to one or two sources (e.g., "The Tanakh explicitly teaches…"), so long as this scope is clearly stated.
      * For generalized claims across multiple scriptures, LSV allows:
      * Support from at least one of the relevant texts
      * As long as none of the other sources directly contradict the claim
      * Historical fact or pure logic may also be used independently, even without explicit textual support, as long as the claim is not contradicted
      Example: A historical event like the destruction of the Second Temple (70 CE) can be included if it aligns with scripture or logic and is not opposed by the text.



      3. Peer-Level Human Validation Layer To ensure maximum integrity and eliminate blind spots:
      * Every finalized claim should be peer-reviewed by another individual applying the LSV method.
      * Any challenge to a claim must itself meet LSV standards—only using literal text, verifiable history, or logic to critique.
      * This creates a closed validation loop, where both the claim and any dispute about it are held to the same rules.
      * Human validation guards against confirmation bias, AI oversight, or subtle misuse of sources.

      ======================

      Statement to validate:
      "#{claim.content}"

      If available, also consider the following evidence provided by the user:
      "#{claim.evidence}"

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
