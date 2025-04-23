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
      Permitted Source:
      {
        "source_record": "Quran",
        "source_language": "Arabic",
        "translation_reference": "Yusuf Ali",
        "source_version": "Uthmanic codex",
        "lsv_framework": {
        "description": "Literal Source Verification (LSV) checks claims strictly against the literal content of the Quran. No theology, doctrine, commentary, or modern reinterpretation is permitted. The Quran is treated solely as a text. All language must be validated using the definitions established by the Quran itself or classical Arabic usage contemporary to its revelation.",
        "permitted_sources": [
        "Quran (original Arabic, with Yusuf Ali English for reference only)",
        "Verifiable historical facts about the Quran's transmission (e.g., manuscript evidence)",
        "Pure logic used only to bridge literal facts explicitly stated in the Quran"
        ],
        "excluded_sources": [
        "All tafsir (Quranic commentaries)",
        "All hadith (sayings or traditions attributed to Muhammad)",
        "All Islamic jurisprudence (fiqh)",
        "All theological systems and doctrines, including but not limited to:",
        " - Sunni theology (Ash'arite, Maturidi, Salafi)",
        " - Shia theology (Twelver, Ismaili, Zaidi)",
        " - Sufi mysticism",
        " - Mu'tazila rationalism",
        " - Ahmadiyya doctrines",
        " - Ijma (scholarly consensus)",
        " - Caliphate rulings or fatwas",
        " - Any historical or modern Islamic ideological framework",
        "Modern reinterpretation or symbolic projection of meaning",
        "Cultural assumptions or retroactive moral worldviews",
        "Any metaphorical or mystical reading not explicitly stated in the Quran",
        "Modern Arabic or theological dictionaries for word definitions"
        ],
        "evaluation_criteria": [
        "Claim must be directly stated or logically bridged from literal Quranic text",
        "Every keyword in the claim must be validated using Quran-internal definitions or classical Arabic",
        "No inference, symbolic expansion, or extrapolation is allowed",
        "All metaphors (mathal) or similitudes must be treated as literal only if their meaning is explained in the Quran",
        "Claims involving metaphors with no literal explanation must be marked 'Inconclusive'",
        "Supernatural elements stated literally in the Quran are accepted as-is (no reinterpretation)",
        "Claims must be checked against all Quran verses for internal contradiction"
        ],
        "figurative_language_handling": {
        "rule": "If the Quran uses a metaphor, parable, or similitude (e.g., 'mathal'), the validator must determine if the meaning is explicitly explained within the Quran itself. If the meaning is not explained, the validator must mark the claim as 'Inconclusive'.",
        "keywords": ["mathal", "amthal", "example", "like unto", "as if"],
        "allowed_conditions": [
        "Literal wording is used and does not rely on interpretation",
        "A literal explanation follows or is referenced elsewhere in the Quran"
        ],
        "disallowed_conditions": [
        "Relying on tafsir or theology to explain the example",
        "Using metaphor to stretch meaning beyond literal linguistic structure",
        "Assuming symbolic meaning from cultural or religious tradition"
        ],
        "example": {
        "acceptable": "Parable of the spider in 29:41 is valid only if explained in another verse",
        "unacceptable": "Do not use external theological sources to explain 'Light' in 24:35"
        }
        },
        "word_definition_handling": {
        "method": "Each keyword or concept in the claim must be validated against either:",
        "sources": [
        "The Quran itself (cross-verse definitions)",
        "Classical Arabic lexicons such as Lisan al-Arab",
        "Verified historical linguistic studies of Quranic Arabic"
        ],
        "note": "Modern dictionaries or definitions rooted in theology must be excluded"
        }
        },
        "claim_validation_task": {
        "claim_text": "[Insert specific claim here]",
        "task": "Evaluate whether the above claim is supported, contradicted, or unmentioned by the Quran according to the LSV framework",
        "output_format": {
        "result": "True / False / Inconclusive",
        "evidence": [
        {
        "type": "QuranVerse",
        "reference": "Surah:Ayah",
        "arabic": "[Full Arabic verse here]",
        "translation": "[Yusuf Ali translation here]"
        }
        ],
        "definition_audit": [
        {
        "term": "[keyword]",
        "used_in_claim": true,
        "quran_references": ["Surah:Ayah"],
        "source": "Quran + Classical Arabic"
        }
        ],
        "reasoning_summary": "Explain verdict using Quran-only evidence and logic. Highlight exact verses, keyword meanings, and why claim is True, False, or Inconclusive."
        }
        },
        "instructions": "This validator must assess the claim using only the literal text of the Quran, without any interpretation from religious schools, theology, or cultural bias. All claim terms must be validated word-for-word using Quran or classical Arabic sources. No tafsir, hadith, or Islamic doctrines may be referenced directly or indirectly. Symbolic meanings are allowed only if explicitly explained in the Quran itself."
      }
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
