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

  private

  def build_prompt(claim, error)
    {
      system: "You are an expert assistant for claim validation. Help users improve their claims to pass strict validation. Always explain the error and provide actionable suggestions.",
      user: "A user submitted the following claim, which failed validation.\n\nClaim: #{claim}\n\nValidation Error: #{error}\n\nPlease explain why this claim failed and provide clear, actionable suggestions to improve it so it will pass the validator. Respond conversationally as an AI assistant."
    }
  end
end 