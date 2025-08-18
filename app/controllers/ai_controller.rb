class AiController < ApplicationController
  include ActionController::Live
  before_action :authenticate_user!
  before_action :check_ai_access

  def claim_suggestion
    response.headers['Content-Type'] = 'text/event-stream'
    claim = params[:claim]
    error = params[:error]

    Rails.logger.info "Claim suggestion called with claim: #{claim}, error: #{error}"

    prompt = build_prompt(claim, error)
    client = OpenAI::Client.new(
      access_token: openai_api_key,
      log_errors: true
    )

    begin
      client.chat(
        parameters: {
          model: "gpt-4o",
          messages: [
            { role: "system", content: prompt[:system] },
            { role: "user", content: prompt[:user] }
          ],
          temperature: 0.2,
          stream: proc { |chunk, _bytesize|
            content = chunk.dig("choices", 0, "delta", "content")
            if content
              Rails.logger.info "Streaming content: #{content}"
              response.stream.write(content)
            end
          }
        }
      )
    rescue => e
      Rails.logger.error "AI service error: #{e.message}"
      response.stream.write("Sorry, there was a problem with the AI service.")
    ensure
      response.stream.close
    end
  end

  def evidence_suggestion
    response.headers['Content-Type'] = 'text/event-stream'
    messages = params[:messages] || []

    system_prompt = {
      role: "system",
      content: <<~PROMPT
        You are an expert assistant for evidence suggestion. For every user request, you MUST respond ONLY with a single valid JSON object with the following fields:

        {
          "explanation": "A short explanation of why this evidence is relevant.",
          "reference": "Reference name and number ONLY (e.g., Surah Al-Fath 48:29, John 3:16, etc.). DO NOT include the word 'Reference:' or any heading before the reference. Output the reference directly.",
          "original": "The original verse or passage in its original language.",
          "translation": "A clear English translation of the verse or passage."
        }

        Do NOT include any commentary, markdown, triple backticks, or text outside the JSON. Do NOT say 'Here is the evidence:' or ask any questions. If you do NOT return a single valid JSON object, your answer will be discarded and the user will see an error. If you cannot find evidence, return a JSON object with empty strings for all fields.
      PROMPT
    }
    messages = messages.reject { |msg| msg["role"] == "system" }
    messages.unshift(system_prompt)

    client = OpenAI::Client.new(
      access_token: openai_api_key,
      log_errors: true
    )

    begin
      client.chat(
        parameters: {
          model: "gpt-4o",
          messages: messages,
          temperature: 0.2,
          stream: proc { |chunk, _bytesize|
            content = chunk.dig("choices", 0, "delta", "content")
            response.stream.write(content) if content
          }
        }
      )
    rescue => e
      response.stream.write("Sorry, there was a problem with the AI service.")
    ensure
      response.stream.close
    end
  end

  def claim_guidance
    question = params[:question]
    client = OpenAI::Client.new(
      access_token: openai_api_key,
      log_errors: true
    )

    system_prompt = <<~PROMPT
      You are a Claim Structure Coach for VeriFaith.
      Your job is to help users write a claim that will pass the Literal Source Verification (LSV) validator.

      Strict LSV rules:
      - The claim must be a SINGLE, short, direct fact, stated ABSOLUTELY.
      - No speculation, no compound ideas, no vague or ambiguous language.
      - No arguments, theories, interpretations, or generalizations.

      Your job:
      - If the user asks for help, explain the rules in simple terms and give examples of good and bad claims.
      - If the user provides a draft, analyze it and give specific, actionable feedback on how to improve it to meet the LSV rules.
      - Encourage the user to rewrite their claim, step by step, until it is short, single, absolute, and clear.

      Never judge the truth of the claim, only its structure and wording.
      Never output JSON, only conversational guidance and examples.
    PROMPT

    response.headers['Content-Type'] = 'text/event-stream'
    client.chat(
      parameters: {
        model: "gpt-4o",
        messages: [
          { role: "system", content: system_prompt },
          { role: "user", content: question }
        ],
        stream: proc do |chunk, _bytesize|
          response.stream.write chunk.dig("choices", 0, "delta", "content").to_s
        end
      }
    )
  rescue => e
    response.stream.write "Sorry, there was a problem getting guidance."
  ensure
    response.stream.close
  end

  def generate_evidence
    # Check if user has AI evidence entitlement
    unless current_user.can_generate_ai_evidence?
      render json: { error: "AI evidence generation not available in your plan" }, status: :forbidden
      return
    end

    # Check usage limits
    remaining = current_user.ai_evidence_remaining
    if remaining == 0
      render json: { error: "AI evidence limit reached. Please upgrade your plan." }, status: :forbidden
      return
    end

    # Record usage BEFORE generating (to prevent race conditions)
    current_user.record_ai_evidence_usage

    # Proceed with AI evidence generation
    # ... your AI logic here ...

    # Return success with updated remaining count
    render json: {
      success: true,
      remaining_ai_evidence: current_user.ai_evidence_remaining,
      message: "AI evidence generated successfully"
    }
  end

  def analytics
    # Check if user has advanced analytics entitlement
    unless current_user.can_access_advanced_analytics?
      render json: { error: "Advanced analytics not available in your plan" }, status: :forbidden
      return
    end

    # Proceed with analytics
    # ... your analytics logic here ...
  end

  private

  def check_ai_access
    unless current_user.has_entitlement?('ai_evidence_limitation')
      redirect_to subscription_settings_path,
                  alert: "AI features require an active subscription. Please upgrade your plan."
    end
  end

  def build_prompt(claim, error)
    {
      system: "You are an expert assistant for claim validation. Help users improve their claims to pass strict validation. Always explain the error and provide actionable suggestions.",
      user: "A user submitted the following claim, which failed validation.\n\nClaim: #{claim}\n\nValidation Error: #{error}\n\nPlease explain why this claim failed and provide clear, actionable suggestions to improve it so it will pass the validator. Respond conversationally as an AI assistant."
    }
  end

  def openai_api_key
    Rails.application.secrets.dig(:openai, :api_key)
  end
end
