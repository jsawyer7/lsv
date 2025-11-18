require 'openai'

class TextContentValidationService
  def initialize(text_content)
    @text_content = text_content
    @source = text_content.source
    @book = text_content.book
    @chapter = text_content.unit_group
    @verse = text_content.unit
  end

  def validate_content
    Rails.logger.info "Validating content for #{@text_content.unit_key}"
    
    unless @text_content.content.present?
      return {
        status: 'error',
        error: 'Content not populated yet',
        is_accurate: false
      }
    end

    result = perform_validation
    
    if result[:status] == 'success'
      update_validation_fields(result)
      log_validation(result)
      result
    else
      Rails.logger.error "Validation failed: #{result[:error]}"
      result
    end
  rescue => e
    Rails.logger.error "Error in TextContentValidationService: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    {
      status: 'error',
      error: e.message,
      is_accurate: false
    }
  end

  private

  def perform_validation
    max_retries = 3
    retry_count = 0
    
    begin
      client = OpenAI::Client.new(
        access_token: openai_api_key,
        log_errors: true,
        request_timeout: 120 # 2 minute timeout
      )

      prompt = build_validation_prompt

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
          temperature: 0.0, # Zero temperature for strict validation
          response_format: { type: "json_object" }
        }
      )

      ai_response = response.dig("choices", 0, "message", "content")
      
      if ai_response.blank?
        return { status: 'error', error: 'Empty response from AI', is_accurate: false }
      end

      # Parse JSON response
      parsed = JSON.parse(ai_response)
      
      lsv_violations = parsed['lsv_rule_violations'] || []
      character_accurate = parsed['is_accurate'] == true
      
      # If there are LSV rule violations, the overall accuracy is compromised
      # Even if characters match, the content violates LSV rules
      overall_accurate = character_accurate && lsv_violations.empty?
      
      {
        status: 'success',
        is_accurate: overall_accurate,
        character_accurate: character_accurate,
        accuracy_percentage: parsed['accuracy_percentage'] || 0,
        character_accuracy: parsed['character_accuracy'] || {},
        discrepancies: parsed['discrepancies'] || [],
        lsv_rule_violations: lsv_violations,
        validation_notes: parsed['validation_notes'] || '',
        raw_response: ai_response
      }
    rescue JSON::ParserError => e
      Rails.logger.error "Failed to parse validation response: #{e.message}"
      Rails.logger.error "Raw response: #{ai_response}"
      { status: 'error', error: "Failed to parse validation response: #{e.message}", is_accurate: false }
    rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ETIMEDOUT => e
      retry_count += 1
      if retry_count < max_retries
        wait_time = retry_count * 2
        Rails.logger.warn "Timeout error (attempt #{retry_count}/#{max_retries}): #{e.message}. Retrying in #{wait_time}s..."
        sleep wait_time
        retry
      else
        Rails.logger.error "Max retries reached. Error: #{e.message}"
        { status: 'error', error: "Network timeout after #{max_retries} attempts: #{e.message}", is_accurate: false }
      end
    rescue SocketError, Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Errno::ENETUNREACH => e
      retry_count += 1
      if retry_count < max_retries
        wait_time = retry_count * 2
        Rails.logger.warn "Network error (attempt #{retry_count}/#{max_retries}): #{e.message}. Retrying in #{wait_time}s..."
        sleep wait_time
        retry
      else
        Rails.logger.error "Max retries reached. Error: #{e.message}"
        { status: 'error', error: "Network connection failed after #{max_retries} attempts: #{e.message}. Please check your internet connection.", is_accurate: false }
      end
    rescue => e
      Rails.logger.error "Error performing validation: #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")
      { status: 'error', error: "#{e.class.name}: #{e.message}", is_accurate: false }
    end
  end

  def system_prompt
    <<~PROMPT
      You are a strict textual validation expert. Your job is to verify that a provided text is 100% character-by-character accurate compared to the source.
      
      You must:
      1. Compare the provided text character-by-character with the source
      2. Identify ANY discrepancies (missing characters, extra characters, wrong characters, punctuation differences, spacing differences)
      3. Report accuracy as a percentage (100% = perfect match)
      4. List all discrepancies with exact positions and differences
      5. Validate that word-for-word translation comments follow LSV rules
      
      CRITICAL:
      - Even a single character difference means the text is NOT 100% accurate
      - Punctuation, diacritics, spacing, and capitalization must all match exactly
      - Report discrepancies with specific character positions when possible
      
      LSV RULE VALIDATION:
      Check word-for-word translation comments for violations of: "No external philosophical, theological, or cultural meanings may be imported."
      - Flag any comments that add philosophical definitions, classical Greek philosophical concepts, or theological interpretations
      - Flag any comments that import modern lexicon expansions with external meanings
      - Flag any comments that add cultural or historical context beyond basic dictionary definitions
      - Comments should ONLY contain: dictionary meanings, grammatical notes, alternative dictionary translations, basic linguistic information
    PROMPT
  end

  def build_validation_prompt
    <<~PROMPT
      Source: #{@source.name}
      Book: #{@book.std_name} (#{@book.code})
      Chapter: #{@chapter}
      Verse: #{@verse}
      Source Language: #{@source.language.name}
      
      Please validate the following text against #{@source.name} for #{@book.std_name} #{@chapter}:#{@verse}:
      
      TEXT TO VALIDATE:
      "#{@text_content.content}"
      
      WORD-FOR-WORD TRANSLATION COMMENTS TO VALIDATE:
      #{@text_content.word_for_word_translation.to_json}
      
      Please provide validation in JSON format:
      
      {
        "is_accurate": true/false,
        "accuracy_percentage": 0-100,
        "character_accuracy": {
          "total_characters": number,
          "matching_characters": number,
          "discrepancies_count": number
        },
        "discrepancies": [
          {
            "position": "approximate position in text",
            "expected": "what should be there",
            "found": "what is actually there",
            "type": "missing/extra/wrong/punctuation/spacing"
          }
        ],
        "lsv_rule_violations": [
          {
            "word": "the word that has the violation",
            "comment": "the problematic comment text",
            "violation_type": "philosophical/theological/cultural/lexicon_expansion",
            "issue": "description of what violates the LSV rule"
          }
        ],
        "validation_notes": "Detailed notes about the validation, including any LSV rule violations"
      }
      
      IMPORTANT:
      - Compare character-by-character
      - Report 100% accuracy ONLY if every single character matches exactly
      - Include all discrepancies, no matter how small
      - Note any differences in punctuation, diacritics, spacing, or capitalization
      
      LSV RULE CHECK:
      Review the word-for-word translation comments and check for violations of: "No external philosophical, theological, or cultural meanings may be imported."
      - Look for philosophical definitions, classical Greek philosophical concepts, theological interpretations
      - Look for modern lexicon expansions that import external meanings
      - Look for cultural or historical context beyond basic dictionary definitions
      - If violations are found, set is_accurate to false and list them in lsv_rule_violations array
      - Comments should ONLY contain: dictionary meanings, grammatical notes, alternative dictionary translations
    PROMPT
  end

  def update_validation_fields(result)
    @text_content.update!(
      content_validated_at: Time.current,
      content_validated_by: 'gpt-4-turbo',
      content_validation_result: {
        is_accurate: result[:is_accurate],
        accuracy_percentage: result[:accuracy_percentage],
        character_accuracy: result[:character_accuracy],
        discrepancies: result[:discrepancies],
        lsv_rule_violations: result[:lsv_rule_violations] || [],
        validated_at: Time.current.iso8601
      },
      validation_notes: result[:validation_notes]
    )
  end

  def log_validation(result)
    # Log the validation request/response
    TextContentApiLog.create!(
      text_content_id: @text_content.id,
      api_endpoint: 'validate_content',
      request_data: {
        source: @source.name,
        book: @book.std_name,
        chapter: @chapter,
        verse: @verse,
        content_to_validate: @text_content.content
      },
      response_data: {
        is_accurate: result[:is_accurate],
        accuracy_percentage: result[:accuracy_percentage],
        discrepancies_count: result[:discrepancies]&.count || 0
      },
      raw_response: result[:raw_response],
      status: result[:is_accurate] ? 'success' : 'validation_failed'
    )
  rescue => e
    Rails.logger.error "Failed to log validation: #{e.message}"
  end

  def openai_api_key
    Rails.application.secrets.dig(:openai, :api_key) || ENV['OPENAI_API_KEY']
  end
end

