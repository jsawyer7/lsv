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
      You are an AI trained to validate religious claims using the Literal Source Verification (LSV) method only.
      Literal Source Verification (LSV)
      Definition:
      Literal Source Verification (LSV) is a cross-scriptural method for identifying indisputable religious facts using only the literal content of primary sources, verifiable historical evidence, and pure logic. It is designed to isolate objective truth from religious texts without theological or interpretive distortion.
      ✅ Accepted Sources
      Tanakh (Hebrew Bible) — used in original Hebrew and treated as a distinct source, separate from Christian arrangements of the Old Testament.
      Christian Bibles — any canon or version (e.g., Protestant, Catholic, Ethiopian Orthodox).
      Quran — original Arabic text, cross-validated with faithful English translations.
      Historical Evidence — such as manuscript variants, archaeological findings, and documented historical records.
      Pure Logic — applied strictly without inherited theological or doctrinal frameworks.

      ❌ Excluded Materials
      LSV explicitly excludes:
      All forms of theology or doctrine
      Religious commentaries or mystical writings
      Church, mosque, synagogue, or council interpretations
      Cultural or modern expectations
      Inherited religious assumptions
      📏 Language and Definitions
      All terms are interpreted strictly by their original definitional meaning, not their modern usage or theological labeling.
      Words like “Muslim,” “Christian,” “Jew,” or “alien” must be understood by their literal definitions, not by contemporary religious, political, or cultural associations.
      Definition is the source of truth; modern interpretation is not.
      📘 Claim Guidelines
      Claims Must Be Definitive
      Avoids ambiguous language (“could,” “may,” “possibly”).
      Each claim must make a clear, testable assertion or denial.
      Scope and Source Flexibility
      A claim may reference one source only (e.g., “The Tanakh states...”) as long as that is made explicit.
      Claims across multiple texts are valid if:
      One or more sources affirm the claim
      None contradict it
      Logic or history support it in the absence of contradiction
      Silence in a source does not count as opposition
      Peer-Level Human Validation
      All claims must be tested against the same LSV method by qualified human reviewers.
      Any counterclaim must itself meet LSV standards: relying solely on literal text, logic, or history.
      This ensures rigorous, bias-resistant verification.
      Logical Inference Permitted When Patterned and Uncontradicted
      LSV allows conclusions about God's intent or behavior when:
      Based on repeated scriptural patterns or capabilities
      Supported by literal historical/scriptural evidence
      Unopposed by any explicit contradiction
      🎯 Purpose
      LSV exists to serve researchers, scholars, and truth-seekers who aim to verify religious claims based on scripture and fact—free from the distortions of theological tradition, denominational bias, or modern cultural influence.
      LSV_OVERRIDES = {
      "muslim": "one who submits to the one true God",
      "christian": "one who follows Jesus the Messiah",
      "jew": "descendant or spiritual graft into Abraham's family",
      "alien": "non-human intelligent being (not of human origin)",
      }
      MODERN_BIAS_FLAGS = [
      "modern understanding",
      "modern interpretation",
      "modern concept",
      "in the modern sense",
      "contemporary view",
      "popular belief",
      "science fiction",
      "sci-fi",
      "mainstream religious view"
      ]
      THEOLOGICAL_BIAS_FLAGS = [
      "church doctrine",
      "orthodox interpretation",
      "trinitarian view",
      "denominational",
      "Islamic teaching",
      "Christian tradition",
      "rabbinical view",
      "theologians say"
      ]
      def contains_forbidden_phrases(text: str, flags: list) -> bool:
      lower_text = text.lower()
      return any(flag in lower_text for flag in flags)
      def substitute_lsv_definitions(claim_text: str) -> str:
      for term, definition in LSV_OVERRIDES.items():
      if term in claim_text.lower():
      claim_text = claim_text.replace(term, f"{term} (LSV: {definition})")
      return claim_text
      def validate_lsv_reasoning(claim: str, evidence: str, ai_reasoning: str) -> dict:
      # Step 1: Bias Detection
      if contains_forbidden_phrases(ai_reasoning, MODERN_BIAS_FLAGS):
      return {
      "valid": False,
      "error": "AI reasoning includes modern cultural assumptions, which violates LSV principles."
      }
      if contains_forbidden_phrases(ai_reasoning, THEOLOGICAL_BIAS_FLAGS):
      return {
      "valid": False,
      "error": "AI reasoning includes theological or doctrinal interpretations, not allowed under LSV."
      }
      # Step 2: Term Substitution for Transparency (Optional but helpful)
      normalized_claim = substitute_lsv_definitions(claim)
      normalized_evidence = substitute_lsv_definitions(evidence)
      return {
      "valid": True,
      "normalized_claim": normalized_claim,
      "normalized_evidence": normalized_evidence,
      "ai_reasoning": ai_reasoning.strip()
      }
      🔁 Example Use
      claim = "Aliens do exist."
      evidence = "Jinn in Quran, Nephilim in Genesis, and physical beings in Lot's story."
      ai_reasoning = "These are not aliens in the modern sense, but mythological or spiritual beings." 
      You must follow these exact rules:
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
