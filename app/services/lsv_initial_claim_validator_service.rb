require 'openai'
require 'json'
require 'yaml'

class LsvInitialClaimValidatorService
  def initialize(claim_text)
    @claim_text = claim_text
  end

  def run_validation!
    response = send_to_openai
    parse_response_json(response)
  rescue => e
    Rails.logger.error "OpenAI Error: #{e.message}"
    {
      valid: false,
      reason: "An error occurred while validating the claim."
    }
  end

  private

  def load_prompt_template
    template_path = Rails.root.join('config', 'prompts', 'claim_initial_validator.yml')
    YAML.load_file(template_path)
  end

  def build_prompt
    template = load_prompt_template
    
    # Replace placeholders in the template
    prompt = template.transform_values do |content|
      next content unless content.is_a?(String)
      content.gsub('{{claim}}', @claim_text.to_s)
    end

    prompt
  end

  def send_to_openai
    client = OpenAI::Client.new(
      access_token: openai_api_key,
      organization_id: openai_organization_id,
      log_errors: true
    )

    prompt = build_prompt

    client.chat(
      parameters: {
        model: "gpt-4",
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
    result = JSON.parse(json_str)

    {
      valid: result["valid"],
      reason: result["reason"]
    }
  rescue JSON::ParserError => e
    Rails.logger.error "Failed to parse OpenAI response JSON: #{e.message}"
    {
      valid: false,
      reason: "Failed to validate the claim format."
    }
  end

  def openai_api_key
    Rails.application.secrets.dig(:openai, :api_key)
  end

  def openai_organization_id
    Rails.application.secrets.dig(:openai, :organization_id)
  end
end
