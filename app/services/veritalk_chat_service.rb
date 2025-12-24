require 'openai'

class VeritalkChatService
  # Token budget constants
  RAW_WINDOW_TOKEN_BUDGET = 2000 # ~55-65% of input context budget
  MIN_TURNS_TO_INCLUDE = 2 # Always include at least 2 complete turns

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

    # Build messages payload following exact spec order
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

    
    cleaned_text = extract_assistant_response(assistant_text)

    # Persist the cleaned assistant message
    @conversation.conversation_messages.create!(
      role: 'assistant',
      content: cleaned_text
    )

    # Update rolling summary if needed (after assistant response)
    update_rolling_summary_if_needed!

    # Increment message count since last summary
    @conversation.increment!(:message_count_since_summary)
  rescue => e
    Rails.logger.error "VeriTalk stream error: #{e.message}"
    raise
  end

  private

  # Build messages payload following exact spec order
  def build_messages_payload
    messages = []

    # 1. system: VERITALK_CONTRACT (the main contract)
    messages << {
      role: "system",
      content: system_prompt
    }

    # 2. system: USER_PROFILE_MEMORY (stable preferences + constraints)
    user_profile = user_profile_memory
    if user_profile.present?
      messages << {
        role: "system",
        content: "USER_PROFILE_MEMORY:\n#{user_profile}"
      }
    end

    # 3. system: ROLLING_CONVERSATION_SUMMARY (latest only)
    rolling_summary = @conversation.rolling_summary
    if rolling_summary.present?
      messages << {
        role: "system",
        content: "ROLLING_CONVERSATION_SUMMARY:\n#{rolling_summary}"
      }
    end

    # 4. system: SOURCE TEXTS (if verse references detected)
    verse_texts = detect_and_fetch_verse_texts
    if verse_texts.present?
      messages << {
        role: "system",
        content: "SOURCE TEXTS (exact; quote from these only):\n#{verse_texts}"
      }
    end

    # 5. assistant/user: RECENT_RAW_MESSAGES_WINDOW (verbatim recent messages, token-budgeted)
    recent_messages = select_recent_messages_window
    recent_messages.each do |msg|
      messages << {
        role: msg.role,
        content: msg.content
      }
    end

    # 6. user: CURRENT_USER_MESSAGE
    messages << {
      role: "user",
      content: @user_message_text
    }

    messages
  end

  def system_prompt
    # Get the active validator from database, or fallback to default
    validator = VeritalkValidator.current

    if validator&.system_prompt.present?
      Rails.logger.info "VeriTalk: Using database validator '#{validator.name}' (ID: #{validator.id}, Version: #{validator.version})"
      validator.system_prompt
    else
      Rails.logger.warn "VeriTalk: No active validator found in database, using default fallback prompt"
      # Fallback to default prompt if no validator is set up
      default_system_prompt
    end
  end

  def default_system_prompt
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

  # USER_PROFILE_MEMORY (stable preferences + constraints)
  def user_profile_memory
    return nil unless @user.veritalk_profile_memory.present?

    @user.veritalk_profile_memory
  end

  # Select recent messages within token budget (token-budgeted, not hard-count)
  def select_recent_messages_window
    all_messages = @conversation.conversation_messages.order(position: :asc)
    return [] if all_messages.empty?

    # Start with most recent and work backward
    selected = []
    token_count = 0
    messages_to_check = all_messages.last(20).reverse # Check last 20 messages max

    messages_to_check.each do |msg|
      msg_tokens = estimate_tokens(msg.content)

      # Always include at least MIN_TURNS_TO_INCLUDE complete turns
      if selected.length < MIN_TURNS_TO_INCLUDE * 2
        selected.unshift(msg)
        token_count += msg_tokens
      elsif token_count + msg_tokens <= RAW_WINDOW_TOKEN_BUDGET
        selected.unshift(msg)
        token_count += msg_tokens
      else
        # If a single message is huge, truncate it or exclude it
        if msg_tokens > RAW_WINDOW_TOKEN_BUDGET * 0.5 # Message is >50% of budget
          # Exclude huge messages and rely on rolling summary
          Rails.logger.warn "VeriTalk: Excluding large message (#{msg_tokens} tokens) from window, relying on rolling summary"
          break
        else
          # Token budget exceeded, stop adding messages
          break
        end
      end
    end

    # Ensure we have complete turns (user+assistant pairs) when possible
    # If we have an odd number and more than minimum, try to balance
    if selected.length.odd? && selected.length > MIN_TURNS_TO_INCLUDE * 2
      # Remove the oldest message to make it even (complete turns)
      selected.shift
    end

    selected
  end

  def estimate_tokens(text)
    # Rough estimation: ~4 characters per token
    (text.to_s.length / 4.0).ceil
  end

  # Update rolling summary when needed
  def update_rolling_summary_if_needed!
    should_update =
      @conversation.message_count_since_summary >= 10 || # Every 10 messages (8-12 range)
      @conversation.rolling_summary.blank? || # First summary
      goal_or_constraint_changed? || # User changed goals or constraints
      decision_made? || # A decision was made
      major_constraint_introduced? || # Major constraint introduced
      ux_friction_detected? # Notable UX issue discovered

    return unless should_update

    generate_rolling_summary
  rescue => e
    Rails.logger.error "VeriTalk rolling summary update error: #{e.message}"
  end

  def generate_rolling_summary
    # Get messages since last summary update (or all if no summary exists)
    since_time = @conversation.last_summary_update_at || @conversation.created_at
    recent_messages = @conversation
                       .conversation_messages
                       .where("created_at > ?", since_time)
                       .order(position: :asc)

    # If no new messages, use last 10 messages for initial summary
    if recent_messages.empty?
      recent_messages = @conversation.conversation_messages.order(position: :asc).last(10)
    end

    return if recent_messages.empty?

    # Build context for summarization
    previous_summary = @conversation.rolling_summary || "No previous summary."
    messages_text = recent_messages.map { |m| "#{m.role}: #{m.content}" }.join("\n\n")

    summary_prompt = <<~PROMPT
      Update the rolling conversation summary based on the previous summary and new messages.

      Previous summary:
      #{previous_summary}

      New messages since last summary:
      #{messages_text}

      Generate a new rolling summary with these exact fields:
      Thread goal:
      Key decisions:
      Constraints:
      UX/intent notes:
      Open items:

      Instructions:
      - Keep it concise, decision/goal/constraint-oriented
      - Include UX insights and user friction points under "UX/intent notes"
      - Put topic facts under "Key decisions"
      - Put user objections/friction under "UX/intent notes"
      - Do NOT create a theology essay
      - Focus on what decisions were made and why
      - Capture product insights, not just topic summaries
    PROMPT

    begin
      response = @client.chat(
        parameters: {
          model: "gpt-4o",
          messages: [
            {
              role: "system",
              content: "You are a conversation summarizer. Generate structured rolling summaries focusing on goals, decisions, constraints, and UX insights. Always use the exact field format specified."
            },
            { role: "user", content: summary_prompt }
          ],
          temperature: 0.3,
          max_tokens: 500
        }
      )

      new_summary = response.dig("choices", 0, "message", "content")&.strip
      if new_summary.present?
        @conversation.update!(
          rolling_summary: new_summary,
          last_summary_update_at: Time.current,
          message_count_since_summary: 0
        )
        Rails.logger.info "VeriTalk: Updated rolling summary for conversation #{@conversation.id}"
      end
    rescue => e
      Rails.logger.error "VeriTalk rolling summary generation error: #{e.message}"
    end
  end

  def goal_or_constraint_changed?
    # Check if user message contains goal/constraint change indicators
    change_indicators = [
      "now let's", "let's focus on", "change to", "instead of",
      "no quotes", "always show", "prefer", "don't use", "stop using"
    ]

    change_indicators.any? { |indicator| @user_message_text.downcase.include?(indicator) }
  end

  def decision_made?
    # Check if assistant response or user message indicates a decision was made
    decision_indicators = [
      "we will", "we'll", "decision:", "decided", "agreed to", "will use"
    ]

    # Check last assistant message for decisions
    last_assistant = @conversation.conversation_messages.where(role: 'assistant').order(position: :desc).first
    if last_assistant
      decision_indicators.any? { |indicator| last_assistant.content.downcase.include?(indicator) }
    else
      false
    end
  end

  def major_constraint_introduced?
    # Check if a major constraint was introduced
    constraint_indicators = [
      "no quotes unless", "must show", "require", "mandatory", "hard rule"
    ]

    constraint_indicators.any? { |indicator| @user_message_text.downcase.include?(indicator) }
  end

  def ux_friction_detected?
    # Check for UX friction indicators
    friction_indicators = [
      "expected", "wanted", "confusing", "unclear", "frustrating", "doesn't work",
      "should show", "missing", "not showing"
    ]

    friction_indicators.any? { |indicator| @user_message_text.downcase.include?(indicator) }
  end

  # Detect verse references and fetch verse texts from database
  def detect_and_fetch_verse_texts
    verse_references = []

    # Bible pattern: "John 10:30", "1 John 1:1", "Revelation 3:16"
    bible_pattern = /\b(\d?\s*[A-Za-z]+(?:\s+[A-Za-z]+)?)\s+(\d+):(\d+)/i
    @user_message_text.scan(bible_pattern).each do |match|
      book_name = match[0].strip
      chapter = match[1].to_i
      verse = match[2].to_i
      verse_references << { type: :bible, book: book_name, chapter: chapter, verse: verse }
    end

    # Quran pattern: "Quran 2:255", "Surah 2:255", "Qur'an 2:255"
    quran_pattern = /\b(Quran|Qur'an|Surah)\s+(\d+):(\d+)/i
    @user_message_text.scan(quran_pattern).each do |match|
      surah = match[1].to_i
      ayah = match[2].to_i
      verse_references << { type: :quran, surah: surah, ayah: ayah }
    end

    return nil if verse_references.empty?

    # Fetch verse texts from database
    verse_texts = verse_references.map do |ref|
      fetch_verse_text(ref)
    end.compact

    return nil if verse_texts.empty?

    verse_texts.join("\n\n")
  end

  def fetch_verse_text(ref)
    case ref[:type]
    when :bible
      fetch_bible_verse(ref[:book], ref[:chapter], ref[:verse])
    when :quran
      fetch_quran_verse(ref[:surah], ref[:ayah])
    else
      nil
    end
  end

  def fetch_bible_verse(book_name, chapter, verse)
    # Try to find book by name (case-insensitive)
    book = Book.where('LOWER(std_name) = LOWER(?) OR LOWER(code) = LOWER(?)', book_name, book_name).first
    return nil unless book

    # Try to find canonical text first (most reliable - Westcott-Hort 1881)
    begin
      canonical = CanonicalSourceText.find_canonical('WH', book.code, chapter, verse)
      if canonical&.canonical_text.present?
        return "#{book.std_name} #{chapter}:#{verse} (Westcott-Hort 1881):\n#{canonical.canonical_text}"
      end
    rescue => e
      Rails.logger.debug "VeriTalk: Canonical text lookup failed: #{e.message}"
    end

    # Fallback: try to find in text_contents
    text_content = TextContent.joins(:source, :book)
                              .where(books: { code: book.code })
                              .where(unit_group: chapter, unit: verse)
                              .where(sources: { name: ['Westcott-Hort 1881', 'WH'] })
                              .first

    if text_content&.original_text.present?
      return "#{book.std_name} #{chapter}:#{verse}:\n#{text_content.original_text}"
    end

    nil
  end

  def fetch_quran_verse(surah, ayah)
    # Quran verse fetching - implement based on your Quran data structure
    # This is a placeholder - adjust based on your actual Quran source structure
    text_content = TextContent.joins(:source, :book)
                              .where(books: { code: 'QRN' }) # Adjust based on your Quran book code
                              .where(unit_group: surah, unit: ayah)
                              .where(sources: { name: ['Quran'] })
                              .first

    if text_content&.original_text.present?
      return "Quran #{surah}:#{ayah}:\n#{text_content.original_text}"
    end

    nil
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

  def extract_assistant_response(text)
    return text if text.blank?

    # Try to parse as JSON (most common case)
    begin
      parsed = JSON.parse(text.strip)
      if parsed.is_a?(Hash)
        # Check for assistant_response first (normal response)
        if parsed['assistant_response'].present?
          Rails.logger.info "VeriTalk: Extracted assistant_response from JSON response"
          return parsed['assistant_response'].to_s
        # Check for user_followup (redirect/off-topic response)
        # The validator should provide the complete message in user_followup
        elsif parsed['user_followup'].present?
          Rails.logger.info "VeriTalk: Extracted user_followup from JSON response (route: #{parsed['route']})"
          return parsed['user_followup'].to_s
        end
      end
    rescue JSON::ParserError => e
      # Not valid JSON, try other methods
      Rails.logger.debug "VeriTalk: JSON parse failed: #{e.message}"
    end

    # Check if text contains JSON-like structure (starts with { and has response fields)
    # This handles cases where there might be extra whitespace or the JSON is incomplete
    if text.strip.start_with?('{') && (text.include?('assistant_response') || text.include?('user_followup'))
      # Try to extract JSON from the text (might have extra text before/after)
      # Use a more flexible regex to find the JSON object
      json_match = text.match(/\{[\s\S]*\}/m)
      if json_match
        begin
          parsed = JSON.parse(json_match[0])
          if parsed.is_a?(Hash)
            if parsed['assistant_response'].present?
              Rails.logger.info "VeriTalk: Extracted assistant_response from JSON in text"
              return parsed['assistant_response'].to_s
            elsif parsed['user_followup'].present?
              Rails.logger.info "VeriTalk: Extracted user_followup from JSON in text (route: #{parsed['route']})"
              return parsed['user_followup'].to_s
            end
          end
        rescue JSON::ParserError => e
          Rails.logger.debug "VeriTalk: Failed to parse extracted JSON: #{e.message}"
        end
      end
    end

    # Not JSON or no response field, return original text
    Rails.logger.debug "VeriTalk: Response is not JSON or doesn't contain response fields, returning as-is"
    text
  end

  def openai_api_key
    Rails.application.secrets.dig(:openai, :api_key)
  end
end
