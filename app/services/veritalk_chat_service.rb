require 'openai'

class VeritalkChatService
  MAX_RECENT_MESSAGES = 10

  def initialize(user:, conversation:, user_message_text:)
    @user = user
    @conversation = conversation
    @user_message_text = user_message_text.to_s

    @client = OpenAI::Client.new(
      access_token: openai_api_key,
      log_errors: true
    )
  end

  # Streams the assistant response into the given response.stream
  def stream(response)
    # Persist the new user message
    @conversation.conversation_messages.create!(
      role: 'user',
      content: @user_message_text
    )

    # Auto-generate or update topic from conversation if it's still the default
    update_topic_if_needed!

    messages_payload = build_messages_payload

    assistant_text = +""

    @client.chat(
      parameters: {
        model: "gpt-4o",
        messages: messages_payload,
        temperature: 0.3,
        stream: proc do |chunk, _bytesize|
          content = chunk.dig("choices", 0, "delta", "content")
          next unless content

          assistant_text << content
          response.stream.write(content)
        end
      }
    )

    # Persist assistant message
    @conversation.conversation_messages.create!(
      role: 'assistant',
      content: assistant_text
    )

    # Update compact summary lines for future turns
    update_summaries!
  rescue => e
    Rails.logger.error "VeriTalk stream error: #{e.message}"
    raise
  end

  private

  def build_messages_payload
    messages = []

    # Core system behaviour
    messages << {
      role: "system",
      content: system_prompt
    }

    # Add compact summary lines as lightweight memory
    summary_lines = @conversation.conversation_summaries.order(position: :asc).pluck(:content)
    if summary_lines.any?
      summary_text = summary_lines.each_with_index.map { |line, idx| "#{idx + 1}. #{line}" }.join("\n")
      messages << {
        role: "assistant",
        content: "Short summary of this conversation so far:\n#{summary_text}"
      }
    end

    # Add last N full messages (user + assistant) to give detailed recent context
    recent_messages = @conversation
                      .conversation_messages
                      .reorder(position: :asc)
                      .last(MAX_RECENT_MESSAGES)

    recent_messages.each do |msg|
      messages << {
        role: msg.role,
        content: msg.content
      }
    end

    messages
  end

  def system_prompt
    <<~PROMPT
      You are VeriTalk, the AI assistant for VeriFaith.

      ALLOWED TOPICS (you MUST stay inside these):
      - Religion and religious texts (Qur'an, Tanakh, Bible canons, other scriptures).
      - Religious and church history, historical context of faith traditions.
      - Original languages of scriptures (Hebrew, Aramaic, Greek, Arabic, etc.) and linguistics.
      - Translations, translation differences, and textual criticism.
      - Helping users write and refine claims and evidences that follow Literal Source Verification (LSV) rules.

      LSV claim rules (when helping with claims):
      - A claim must be a SINGLE, short, direct fact, stated ABSOLUTELY.
      - No speculation, no compound claims, no vague language.
      - No arguments, theories, or interpretations as "claims" – only literal factual statements.

      STRICT TOPIC LIMITS:
      - If the user asks about anything outside religion, religious history, languages of scriptures, or translations,
        you MUST briefly refuse and gently redirect to a related religious / historical / linguistic angle.
      - Do NOT answer generic programming, medical, financial, or personal life advice questions.

      STYLE:
      - Be clear, concise, and neutral in tone.
      - When relevant, you may suggest how to turn what the user says into a better LSV-style claim or evidence.
    PROMPT
  end

  # Very lightweight, non-AI summary builder that can later be replaced by
  # a dedicated AI-powered summarizer / validator.
  def update_summaries!
    recent_messages = @conversation
                       .conversation_messages
                       .reorder(position: :asc)
                       .last(10)

    # Pair messages roughly as (user, assistant) and build compact lines
    pairs = recent_messages.each_slice(2).to_a

    summary_lines = pairs.map do |user_msg, ai_msg|
      next unless user_msg

      user_text = truncate_content(user_msg.content)
      ai_text = ai_msg ? truncate_content(ai_msg.content) : ""

      if ai_text.present?
        "User: #{user_text} | AI: #{ai_text}"
      else
        "User: #{user_text}"
      end
    end.compact

    ConversationSummary.transaction do
      @conversation.conversation_summaries.destroy_all

      summary_lines.each_with_index do |line, idx|
        @conversation.conversation_summaries.create!(
          content: line,
          position: idx + 1
        )
      end
    end
  rescue => e
    Rails.logger.error "VeriTalk summary update error: #{e.message}"
  end

  def truncate_content(text, max_length: 160)
    return "" if text.blank?
    return text if text.length <= max_length

    "#{text[0, max_length]}…"
  end

  # Auto-generate a topic from the conversation content
  def update_topic_if_needed!
    # Only update if topic is still the default placeholder
    return unless @conversation.topic == "VeriTalk conversation"

    # Get first few messages to generate topic from
    first_messages = @conversation.conversation_messages.order(position: :asc).limit(4)
    return if first_messages.empty?

    conversation_preview = first_messages.map { |m| "#{m.role}: #{m.content}" }.join("\n")

    topic_prompt = <<~PROMPT
      Based on this conversation, generate a short, specific topic title (max 60 characters).
      Focus on the main subject: religious text, historical event, language/translation question, or claim/evidence help.
      Return ONLY the topic title, nothing else.

      Conversation:
      #{conversation_preview}

      Topic:
    PROMPT

    begin
      response = @client.chat(
        parameters: {
          model: "gpt-4o",
          messages: [
            { role: "system", content: "You are a topic generator. Return only the topic title, no explanations." },
            { role: "user", content: topic_prompt }
          ],
          temperature: 0.3,
          max_tokens: 30
        }
      )

      generated_topic = response.dig("choices", 0, "message", "content")&.strip
      generated_topic = generated_topic.gsub(/^["']|["']$/, '') if generated_topic # Remove quotes if present

      if generated_topic.present? && generated_topic.length <= 100
        @conversation.update!(topic: generated_topic)
      end
    rescue => e
      Rails.logger.error "VeriTalk topic generation error: #{e.message}"
      # Don't fail the whole request if topic generation fails
    end
  end

  def openai_api_key
    Rails.application.secrets.dig(:openai, :api_key)
  end
end
