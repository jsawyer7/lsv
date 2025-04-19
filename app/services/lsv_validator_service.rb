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
      Literal Source Verification (LSV) — Full Framework Definition
      Literal Source Verification (LSV) is a cross-scriptural method for identifying objective, indisputable religious claims using only the literal content of primary sacred texts, verifiable historical evidence, and pure logic. LSV excludes all theological traditions, interpretive commentary, or inherited religious assumptions and focuses strictly on what is actually stated in the permitted sources.
      Permitted Sources:
      Tanakh (Hebrew Bible):
      Treated independently and used in its original Hebrew. It is not subject to Christian rearrangement or reinterpretation under the Old Testament format.
      Christian Bibles:
      Any recognized biblical canon or version is permitted, including but not limited to Protestant (66 books), Catholic (73 books), Eastern Orthodox, and Ethiopian Orthodox versions.
      Quran:
      The original Arabic text is treated as authoritative, with English translations allowed only when linguistically faithful and cross-validated for accuracy.
      Verifiable Historical Records:
      Includes manuscript evidence, archaeological discoveries, historically documented events, and linguistically preserved data.
      Pure Logic:
      Applied with strict boundaries: logic may only be used when it supports or connects literal claims already found in the permitted texts or proven through historical fact. Logic must never introduce assumptions or external ideas.
      Exclusions (Strictly Prohibited in LSV):
      Theology or religious doctrine (e.g., Trinity, Talmudic rulings, Hadith traditions)
      Church, mosque, or synagogue councils or creeds (e.g., Nicene Creed, Sunni/Shia rulings)
      Mystical interpretations (e.g., Kabbalah, Gnosticism, Sufism)
      Interpretive commentaries from any religious or academic tradition
      Modern, cultural, or political assumptions
      Terms or reasoning that reframe scriptural descriptions as metaphor, myth, legend, or symbolic allegory
      Language and Definitions Rule:
      In LSV, definition is the sole source of truth for any term used. Words must be interpreted based on their original, literal meaning — not their modern, popular, religious, or cultural interpretations.

      For example:
      A “Muslim” is defined strictly as “one who submits to God,” not “a member of the Islamic religion.”
      A “Christian” is “one who follows Christ as Messiah,” not “a member of a denominational church.”
      An “alien” refers to “a non-human intelligent being not of human origin,” not a sci-fi extraterrestrial or modern fictional archetype.
      Any use of modern or theological reinterpretations to override literal definitions is strictly disallowed.

      Factual Status of Source Content:
      All permitted texts must be treated as literally accurate for the purposes of claim evaluation, unless directly contradicted by another permitted source, historical record, or logic.
      No event, being, or description found in the Tanakh, Christian Bibles, Quran, or Book of Enoch may be labeled as:
      “myth”
      “mythological”
      “legendary”
      “allegory”
      “symbolic”
      Unless such a label is stated explicitly in the source or proven false by historical/logical contradiction.
      To do otherwise is to introduce interpretive or academic bias, which violates the foundation of LSV.

      Claim Rules and Validation Guidelines:
      Definitive Language Only:
      Claims must be clear and factual.
      Ambiguous phrasing such as “may,” “might,” “could,” “possibly,” or “some believe” is disallowed.
      Each claim must assert a specific fact or denial.
      Scope Declaration and Flexibility:
      Claims may reference one specific source (e.g., “The Tanakh states...”) or span multiple scriptures.
      A multi-source claim is valid if:
      It is explicitly affirmed in one or more sources
      It is not contradicted by any other source
      Historical evidence or logic supports it
      Silence in another source does not invalidate it
      Logic and Pattern-Based Inference (Limited Use):
      Inference about God's will or behavior is allowed if:
      It follows from repeated patterns across scripture
      It is supported by God's described capabilities or past actions
      No permitted source contradicts the conclusion
      Claims based on “intent” must still be grounded in literal observations and facts.
      Peer-Level Human Validation Required:
      Each claim must undergo peer validation by a human using the same LSV method.
      Any challenge to a claim must also meet LSV standards — no interpretations, doctrines, or emotions allowed.
      Peer review ensures the system resists personal error and remains fully testable.
      Purpose and Intended Use:
      LSV is designed for researchers, scholars, interfaith investigators, and individuals seeking religious truth grounded in scripture, fact, and logic — not theology.
      It offers a rigorous standard for verifying religious claims independently of inherited traditions, denomination, or belief system. Its goal is not to persuade by faith, but to establish what can be proven true across accepted sources.
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
