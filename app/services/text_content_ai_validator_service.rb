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
      You are a validator for biblical text sources. Your job is to answer YES/NO questions about whether specific verses exist in a specific source.

      CRITICAL RULES:
      1. You must verify verses that exist in the EXACT source specified (e.g., "Westcott-Hort 1881 Greek New Testament").
      2. Use your knowledge of standard biblical verse counts as a reference, but verify against the specific source when possible.
      3. If you are UNSURE whether a verse exists, answer "YES" (be conservative - it's better to try creating a verse than to skip it).
      4. Standard verse counts are provided in the prompt for reference - use them to guide your answers.
      5. Only answer "NO" if you are CERTAIN the verse does not exist in the source.
      6. If the verse number is within the standard range for that chapter, answer "YES" unless you have specific knowledge it's missing.

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
    if @current_book_code == 'JHN' || @current_book_code == 'JOH'
      next_book_code = nil
    end

    # Get expected verse count for context
    expected_verses = VerseCountReference.expected_verses(@current_book_code, @current_chapter)
    next_chapter_expected = VerseCountReference.expected_verses(@current_book_code, @current_chapter + 1)
    
    verse_count_context = if expected_verses
      "REFERENCE: Standard verse count for #{@current_book_code} Chapter #{@current_chapter} is #{expected_verses} verses. Current verse is #{@current_verse}. "
    else
      ""
    end
    
    next_verse_context = if expected_verses && (@current_verse + 1) <= expected_verses
      "The next verse (#{@current_verse + 1}) is WITHIN the expected range (#{expected_verses} verses). "
    elsif expected_verses && (@current_verse + 1) > expected_verses
      "The next verse (#{@current_verse + 1}) is BEYOND the expected range (#{expected_verses} verses). "
    else
      ""
    end

    <<~PROMPT
      Source: #{@source_name}
      Current location: #{@current_book_code} #{@current_chapter}:#{@current_verse}
      
      #{verse_count_context}#{next_verse_context}

      Answer these questions about the EXACT source "#{@source_name}".

      Q1: Can you access "#{@source_name}" directly? (YES/NO)
      Q2: Does "#{@source_name}" contain #{@current_book_code} #{@current_chapter}:#{@current_verse + 1}? (YES/NO)
      #{if next_chapter_expected
          "Q3: Does \"#{@source_name}\" contain #{@current_book_code} #{@current_chapter + 1}:1? (YES/NO) - Note: Standard verse count for Chapter #{@current_chapter + 1} is #{next_chapter_expected} verses."
        else
          "Q3: Does \"#{@source_name}\" contain #{@current_book_code} #{@current_chapter + 1}:1? (YES/NO)"
        end}
      Q4: #{next_book_code ? "Does \"#{@source_name}\" contain #{next_book_code} 1:1? (YES/NO)" : "Is the source complete for #{@current_book_code}? (YES/NO)"}
      Q5: Is the source complete (no more verses after #{@current_book_code} #{@current_chapter}:#{@current_verse})? (YES/NO)

      IMPORTANT GUIDELINES:
      - If the verse number is within the standard range for that chapter, answer YES for Q2 unless you have specific knowledge it's missing.
      - If you are UNSURE, answer YES (it's better to try creating a verse than to skip it).
      - Only answer NO if you are CERTAIN the verse does not exist.
      - Use the verse count reference information provided above to guide your answers.

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

