require 'openai'

class TextContentAiValidatorService
  def initialize(source_name:, current_book_code:, current_chapter:, current_verse:)
    @source_name = source_name
    @current_book_code = current_book_code
    @current_chapter = current_chapter
    @current_verse = current_verse
  end

  def validate_structure
    prompt = build_validation_prompt

    begin
      client = OpenAI::Client.new(
        access_token: openai_api_key,
        log_errors: true
      )

      response = client.chat(
        parameters: {
          model: "gpt-4-turbo",
          messages: [
            {
              role: "system",
              content: system_prompt
            },
            {
              role: "user",
              content: prompt
            }
          ],
          temperature: 0.1, # Low temperature for strict validation
          max_tokens: 500
        }
      )

      ai_response = response.dig("choices", 0, "message", "content")
      
      # Parse the AI response
      parsed = parse_ai_response(ai_response)

      # Log the validation request
      log_validation_request(parsed)

      parsed
    rescue => e
      Rails.logger.error "AI Validator Error: #{e.message}"
      {
        status: 'error',
        error: "AI validation failed: #{e.message}",
        can_access_source_by_name: false,
        has_next_verse_in_same_chapter: false,
        has_first_verse_in_next_chapter: false,
        has_first_verse_in_next_book: false,
        is_complete: false,
        verdict: 'error'
      }
    end
  end

  private

  def system_prompt
    <<~PROMPT
      You are a strict validator for biblical text sources. Your job is to answer YES/NO questions about whether specific verses exist in a specific source.

      CRITICAL RULES:
      1. You must ONLY verify verses that exist in the EXACT source specified (e.g., "Westcott-Hort 1881 Greek New Testament").
      2. You must NOT use alternative sources or translations.
      3. You must NOT invent or assume verses exist.
      4. You must answer with ONLY "YES" or "NO" for each question.
      5. If you cannot access or verify the exact source, answer "NO" for that question.

      You will receive questions in this format:
      Q1: Can you access [source name] directly? (YES/NO)
      Q2: Does [source] contain [book] [chapter]:[verse]? (YES/NO)
      Q3: Does [source] contain [book] [chapter]:1? (YES/NO)
      Q4: Does [source] contain [next_book] 1:1? (YES/NO)
      Q5: Is the source complete? (YES/NO)

      Respond ONLY with a JSON object in this exact format:
      {
        "can_access_source_by_name": true/false,
        "has_next_verse_in_same_chapter": true/false,
        "has_first_verse_in_next_chapter": true/false,
        "has_first_verse_in_next_book": true/false,
        "is_complete": true/false,
        "verdict": "verified" or "alert"
      }

      Do NOT include any explanation, commentary, or text outside the JSON object.
    PROMPT
  end

  def build_validation_prompt
    # Determine next book in order
    book_order = TextContentCreationService::BOOK_ORDER
    current_index = book_order.index(@current_book_code)
    next_book_code = current_index && current_index + 1 < book_order.length ? book_order[current_index + 1] : nil

    # For John-only test, don't ask about next book
    if @current_book_code == 'JHN'
      next_book_code = nil
    end

    <<~PROMPT
      Source: #{@source_name}
      Current location: #{@current_book_code} #{@current_chapter}:#{@current_verse}

      Answer these questions about the EXACT source "#{@source_name}". You must verify using ONLY the exact source specified - do NOT use alternative sources or translations.

      Q1: Can you access "#{@source_name}" directly? (YES/NO)
      Q2: Does "#{@source_name}" contain #{@current_book_code} #{@current_chapter}:#{@current_verse + 1}? (YES/NO)
      Q3: Does "#{@source_name}" contain #{@current_book_code} #{@current_chapter + 1}:1? (YES/NO)
      Q4: #{next_book_code ? "Does \"#{@source_name}\" contain #{next_book_code} 1:1? (YES/NO)" : "Is the source complete for #{@current_book_code}? (YES/NO)"}
      Q5: Is the source complete (no more verses after #{@current_book_code} #{@current_chapter}:#{@current_verse})? (YES/NO)

      CRITICAL: You must answer based ONLY on the exact source "#{@source_name}". If you cannot verify a verse exists in this exact source, answer NO.

      Respond with ONLY a JSON object in this exact format:
      {
        "can_access_source_by_name": true/false,
        "has_next_verse_in_same_chapter": true/false,
        "has_first_verse_in_next_chapter": true/false,
        "has_first_verse_in_next_book": #{next_book_code ? "true/false" : "null"},
        "is_complete": true/false,
        "verdict": "verified" or "alert"
      }
    PROMPT
  end

  def parse_ai_response(response_text)
    # Try to extract JSON from response
    json_match = response_text.match(/\{[\s\S]*\}/)
    
    unless json_match
      Rails.logger.error "AI response does not contain valid JSON: #{response_text}"
      return default_error_response
    end

    begin
      parsed = JSON.parse(json_match[0])
      
      {
        status: 'success',
        can_access_source_by_name: parsed['can_access_source_by_name'] == true,
        has_next_verse_in_same_chapter: parsed['has_next_verse_in_same_chapter'] == true,
        has_first_verse_in_next_chapter: parsed['has_first_verse_in_next_chapter'] == true,
        has_first_verse_in_next_book: parsed['has_first_verse_in_next_book'],
        is_complete: parsed['is_complete'] == true,
        verdict: parsed['verdict'] || 'verified'
      }
    rescue JSON::ParserError => e
      Rails.logger.error "Failed to parse AI response JSON: #{e.message}"
      default_error_response
    end
  end

  def default_error_response
    {
      status: 'error',
      error: 'Failed to parse AI response',
      can_access_source_by_name: false,
      has_next_verse_in_same_chapter: false,
      has_first_verse_in_next_chapter: false,
      has_first_verse_in_next_book: false,
      is_complete: false,
      verdict: 'error'
    }
  end

  def log_validation_request(result)
    TextContentApiLog.create!(
      source_name: @source_name,
      book_code: @current_book_code,
      chapter: @current_chapter,
      verse: @current_verse,
      action: 'ai_validate',
      request_payload: {
        source_name: @source_name,
        current_book_code: @current_book_code,
        current_chapter: @current_chapter,
        current_verse: @current_verse
      }.to_json,
      response_payload: result.to_json,
      status: result[:status] == 'success' ? 'success' : 'error',
      error_message: result[:error],
      ai_model_name: 'gpt-4-turbo'
    )
  rescue => e
    Rails.logger.error "Failed to log validation request: #{e.message}"
  end

  def openai_api_key
    Rails.application.secrets.dig(:openai, :api_key)
  end
end

