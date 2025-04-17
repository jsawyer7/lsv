require 'openai'

class LsvValidatorService
  def initialize(claim)
    @claim = claim
  end

  def run_validation!
    response = send_to_openai(@claim)
    {
      badge: parse_badge(response),
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

  def send_to_openai(claim)
    client = OpenAI::Client.new(
      access_token: openai_api_key,
      organization_id: openai_organization_id,
      log_errors: true
    )

    prompt = <<~PROMPT
      Claim: "#{claim.content}"

      Evidence: "#{claim.evidence}"

      You are an LSV validator. Use only the literal text of the Tanakh, Christian Bibles (any canon), and the Quran, along with historical fact and logic. Reject all theology, tradition, and commentary. Score the claim and 
      Return a judgment (✅ True / ❌ False / ⚠️ Unverifiable) and reasoning (2-3 sentences).
    PROMPT

    client.chat(
      parameters: {
        model: "gpt-4o",
        messages: [{ role: "user", content: prompt }],
        temperature: 0.7
      }
    )
  end

  def openai_api_key
    Rails.application.secrets.dig(:openai, :api_key)
  end

  def openai_organization_id
    Rails.application.secrets.dig(:openai, :organization_id)
  end

  def parse_badge(response)
    message = response.dig("choices", 0, "message", "content") || ""
    case message
    when /✅/
      "✅ True"
    when /❌/
      "❌ False"
    when /⚠️/
      "⚠️ Unverifiable"
    else
      "⚠️ Unknown"
    end
  end

  def parse_reasoning(response)
    message = response.dig("choices", 0, "message", "content") || ""
    message.gsub(/✅|❌|⚠️/, "").strip
  end
end
