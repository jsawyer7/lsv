class LsvChallengeClaimService
  VALIDATOR_SOURCES = %w[Quran Tanakh Catholic Ethiopian Protestant Historical].freeze

  def initialize(challenge)
    @challenge = challenge
    @claim = challenge.claim
  end

  def process
    @challenge.update(status: 'processing')
    begin
      VALIDATOR_SOURCES.each do |source|
        response = send_to_openai(@challenge, source)
        json = parse_response_json(response)
        result = {
          badge: parse_badge(json),
          reasoning: parse_reasoning(response),
          primary: parse_primary_source(json)
        }
        @challenge.reasonings.create!(
          source: source,
          response: result[:reasoning],
          result: result[:badge],
          primary_source: result[:primary]
        )
      end

      @challenge.update(status: 'completed')
    rescue => e
      Rails.logger.error("Challenge validation failed: #{e.message}")
      @challenge.update(
        ai_response: "Error processing challenge: #{e.message}",
        status: 'failed'
      )
    end
  end

  private

  def load_prompt_template(source)
    template_path = Rails.root.join('config', 'prompts', "#{source.downcase}_challenge_validator.yml")
    YAML.load_file(template_path)
  end

  def build_prompt(challenge, source)
    template = load_prompt_template(source)
    prompt = template.transform_values do |content|
      next content unless content.is_a?(String)
      content
        .gsub('{{claim_text}}', challenge.claim.content.to_s)
        .gsub('{{challenge_text}}', challenge.text.to_s)
        .gsub('{{reasoning}}', '{{REASONING_PLACEHOLDER}}')
        .gsub('{{result}}', '{{RESULT_PLACEHOLDER}}')
    end
    prompt
  end

  def send_to_openai(challenge, source)
    client = OpenAI::Client.new(
      access_token: openai_api_key,
      organization_id: openai_organization_id,
      log_errors: true
    )
    prompt = build_prompt(challenge, source)
    client.chat(
      parameters: {
        model: "gpt-4o",
        messages: [
          { role: "system", content: prompt["system"] },
          { role: "user", content: prompt["user"] },
          { role: "assistant", content: prompt["assistant"] }
        ],
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
    case response["result"]
    when 'True'
      "✅ True"
    when 'False'
      "❌ False"
    when 'Inconclusive'
      "⚠️ Unverifiable"
    else
      "⚠️ Unknown"
    end
  end

  def parse_primary_source(response)
    case response["primary"]
    when 'True'
      true
    else
      false
    end
  end

  def parse_reasoning(response)
    result = parse_response_json(response)
    result["reasoning_summary"] || "No reasoning provided."
  end

  def openai_api_key
    Rails.application.secrets.dig(:openai, :api_key)
  end

  def openai_organization_id
    Rails.application.secrets.dig(:openai, :organization_id)
  end
end 