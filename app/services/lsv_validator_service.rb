require 'openai'
require 'json'
require 'yaml'
require 'timeout'

class LsvValidatorService
  VALIDATOR_SOURCES = %w[Quran Tanakh Catholic Ethiopian Protestant Historical].freeze

  def initialize(claim)
    @claim = claim
    @client = OpenAI::Client.new(
        access_token: openai_api_key,
        log_errors: true
      )
  end

  def run_validation!
    start_time = Time.now
    Rails.logger.info "Validation started at #{start_time}"

    threads = VALIDATOR_SOURCES.map do |source|
      Thread.new do
        t1 = Time.now
        Rails.logger.info "Starting OpenAI call for #{source} at #{t1}"
        begin
          Rails.logger.info "About to call OpenAI for #{source} with API key: #{openai_api_key[0..10]}... and org: #{openai_organization_id}"
          response = Timeout.timeout(24) { send_to_openai(@claim, source) }
          t2 = Time.now
          Rails.logger.info "Finished OpenAI call for #{source} at #{t2} (duration: #{t2 - t1}s)"
          json = parse_response_json(response)
          {
            badge: parse_badge(json),
            reasoning: parse_reasoning(response),
            primary: parse_primary_source(source),
            source: source
          }
        rescue Timeout::Error
          Rails.logger.error "OpenAI call for #{source} timed out!"
          nil
        rescue => e
          Rails.logger.error "OpenAI call for #{source} failed: #{e.message}"
          nil
        end
      end
    end

    results = threads.map(&:value).compact

    results.each do |result|
      reasoning = @claim.reasonings.create!(
        source: result[:source],
        response: result[:reasoning],
        result: result[:badge],
        primary_source: result[:primary]
      )
      # Normalize the reasoning content
      reasoning.normalize_and_save_content!
    end

    store_claim_result(@claim)
    Rails.logger.info "Validation finished at #{Time.now} (total duration: #{Time.now - start_time}s)"
    true
  rescue => e
    Rails.logger.error "OpenAI Error: #{e.message}"
    false
  end

  private

  def store_claim_result(claim)
    primary_reasonings = claim.reasonings.where(primary_source: true)
    if primary_reasonings.any? { |r| r.result == '❌ False' }
      claim.update(result: '❌ False', state: 'ai_validated')
    elsif primary_reasonings.all? { |r| r.result == '✅ True' } && primary_reasonings.any?
      claim.update(result: '✅ True', state: 'ai_validated', fact: true)
    end
  end

  def load_prompt_template(source)
    template_path = Rails.root.join('config', 'prompts', "#{source.downcase}_validator.yml")
    YAML.load_file(template_path)
  end

  def build_prompt(claim, source)
    template = load_prompt_template(source)

    # Group evidences by their sources and format them
    evidence_content = claim.evidences.map do |evidence|
      source_names = evidence.source_names.join(', ')
      "Sources: #{source_names}\n#{evidence.content}"
    end.join("\n\n---\n\n")

    # Replace placeholders in the template
    prompt = template.transform_values do |content|
      next content unless content.is_a?(String)

      content
        .gsub('{{claim}}', claim.content.to_s)
        .gsub('{{evidence}}', evidence_content)
        .gsub('{{reasoning}}', '{{REASONING_PLACEHOLDER}}') # Will be filled by OpenAI
        .gsub('{{result}}', '{{RESULT_PLACEHOLDER}}') # Will be filled by OpenAI
    end

    prompt
  end

  def send_to_openai(claim, source)
    prompt = build_prompt(claim, source)

    @client.chat(
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

  def parse_primary_source(source)
    @claim.primary_sources.include?(source)
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
