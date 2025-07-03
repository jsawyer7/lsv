class AiController < ApplicationController
  include ActionController::Live
  before_action :authenticate_user!

  def claim_suggestion
    response.headers['Content-Type'] = 'text/event-stream'
    claim = params[:claim]
    error = params[:error]

    prompt = build_prompt(claim, error)
    client = OpenAI::Client.new(
      access_token: Rails.application.secrets.dig(:openai, :api_key),
      organization_id: Rails.application.secrets.dig(:openai, :organization_id),
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

  def evidence_suggestion
    response.headers['Content-Type'] = 'text/event-stream'
    question = params[:question]

    prompt = build_evidence_prompt(question)
    client = OpenAI::Client.new(
      access_token: Rails.application.secrets.dig(:openai, :api_key),
      organization_id: Rails.application.secrets.dig(:openai, :organization_id),
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
      access_token: Rails.application.secrets.dig(:openai, :api_key),
      organization_id: Rails.application.secrets.dig(:openai, :organization_id),
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

  private

  def build_prompt(claim, error)
    {
      system: "You are an expert assistant for claim validation. Help users improve their claims to pass strict validation. Always explain the error and provide actionable suggestions.",
      user: "A user submitted the following claim, which failed validation.\n\nClaim: #{claim}\n\nValidation Error: #{error}\n\nPlease explain why this claim failed and provide clear, actionable suggestions to improve it so it will pass the validator. Respond conversationally as an AI assistant."
    }
  end

  def build_evidence_prompt(question)
    {
      system: "You are an expert assistant for evidence suggestion. Help users find a single, clear, and relevant piece of evidence for their claim. Respond conversationally, and always end with: 'Do you want me to add this as evidence? (Yes/No)'",
      user: "A user asked for help with evidence.\n\nQuestion: #{question}\n\nSuggest a single, clear evidence point (e.g., a verse, reference, or fact) and ask if they want to add it as evidence."
    }
  end
end 