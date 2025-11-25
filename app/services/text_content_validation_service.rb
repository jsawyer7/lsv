require 'net/http'
require 'json'
require 'uri'

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
    ai_response = nil
    
    begin
      prompt = build_validation_prompt

      response = call_grok_api(
        model: "grok-3",
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
      )

      # Log response for debugging
      Rails.logger.debug "Grok API response type: #{response.class}"
      Rails.logger.debug "Grok API response keys: #{response.keys.inspect}" if response.is_a?(Hash)
      
      # Extract the content from Grok API response
      # Grok API should return: { "choices": [{ "message": { "content": "..." } }] }
      ai_response = nil
      
      if response.is_a?(Hash)
        if response.key?("choices") && response["choices"].is_a?(Array) && response["choices"].first
          choice = response["choices"].first
          if choice.is_a?(Hash) && choice.key?("message")
            message = choice["message"]
            if message.is_a?(Hash) && message.key?("content")
              ai_response = message["content"]
            end
          end
        end
      end
      
      if ai_response.nil?
        Rails.logger.error "Could not extract content from Grok API response"
        Rails.logger.error "Response structure: #{response.inspect[0..500]}"
        return { status: 'error', error: 'Could not extract content from Grok API response', is_accurate: false }
      end
      
      if ai_response.blank?
        return { status: 'error', error: 'Empty response from Grok API', is_accurate: false }
      end

      # Parse JSON response
      parsed = JSON.parse(ai_response)
      
      lsv_violations = parsed['lsv_rule_violations'] || []
      character_accurate = parsed['character_accurate'] == true || (parsed['character_accurate'].nil? && parsed['is_accurate'] == true)
      lexical_coverage_complete = parsed['lexical_coverage_complete'] != false # Default to true if not specified
      lsv_translation_valid = parsed['lsv_translation_valid'] != false # Default to true if not specified
      
      # Overall accuracy requires ALL checks to pass
      overall_accurate = parsed['is_accurate'] == true || (
        character_accurate && 
        lexical_coverage_complete && 
        lsv_translation_valid && 
        lsv_violations.empty?
      )
      
      {
        status: 'success',
        is_accurate: overall_accurate,
        character_accurate: character_accurate,
        lexical_coverage_complete: lexical_coverage_complete,
        lsv_translation_valid: lsv_translation_valid,
        accuracy_percentage: parsed['accuracy_percentage'] || 0,
        character_accuracy: parsed['character_accuracy'] || {},
        discrepancies: parsed['discrepancies'] || [],
        lexical_coverage_issues: parsed['lexical_coverage_issues'] || [],
        lsv_translation_issues: parsed['lsv_translation_issues'] || [],
        lsv_rule_violations: lsv_violations,
        validation_flags: parsed['validation_flags'] || [],
        validation_notes: parsed['validation_notes'] || '',
        raw_response: ai_response
      }
    rescue JSON::ParserError => e
      Rails.logger.error "Failed to parse Grok API validation response: #{e.message}"
      Rails.logger.error "Raw response: #{ai_response || 'N/A'}"
      { status: 'error', error: "Failed to parse Grok API validation response: #{e.message}", is_accurate: false }
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
      You are a strict textual validation expert. Your job is to verify:
      1. Character-by-character accuracy of the source text
      2. Complete lexical coverage in word-for-word translation
      3. LSV translation built strictly from word-for-word chart
      4. LSV rule compliance (no philosophical/theological imports)
      
      ================================================================================
      VALIDATION REQUIREMENTS
      ================================================================================
      
      1. CHARACTER-BY-CHARACTER ACCURACY
      - Compare the provided text character-by-character with the source
      - Identify ANY discrepancies (missing characters, extra characters, wrong characters, punctuation differences, spacing differences)
      - Report accuracy as a percentage (100% = perfect match)
      - List all discrepancies with exact positions and differences
      - Even a single character difference means the text is NOT 100% accurate
      - Punctuation, diacritics, spacing, and capitalization must all match exactly
      
      2. WORD-FOR-WORD LEXICAL COVERAGE VALIDATION
      For EACH token in the word-for-word chart, you must verify:
      - token: Exact word from source (must match source text)
      - lemma: Root/lemma provided (if applicable for language)
      - morphology: Part of speech/parsing provided (if applicable)
      - base_gloss: Primary literal meaning provided
      - secondary_glosses: ALL other lexically valid meanings included
      - completeness: "COMPLETE" only if ALL lexically valid meanings are included
      - notes: Only grammatical/linguistic information, no theology/philosophy
      
      CRITICAL LEXICAL COVERAGE RULE:
      - If a word has multiple lexically valid meanings, ALL must be in base_gloss + secondary_glosses
      - If any lexically valid sense is missing → completeness must be "INCOMPLETE"
      - Flag as MISSING_LEXICAL_MEANINGS if any token has incomplete lexical range
      - Flag as INVALID_MEANING if a gloss uses a meaning not found in lexicon
      
      3. LSV TRANSLATION VALIDATION
      The LSV translation must:
      - Be built ONLY from the word-for-word chart
      - Use ONLY meanings from base_gloss + secondary_glosses
      - NOT introduce paraphrases, theology, interpretation, smoothing, or denominational bias
      - Reflect ALL valid lexical senses (primary + secondary documented)
      - NOT exceed source text (no additions unless minimal structural support)
      - If LSV translation uses a meaning NOT in word-for-word chart → flag as INVALID_MEANING
      
      4. LSV RULE VALIDATION
      Check word-for-word translation notes for violations of: "No external philosophical, theological, or cultural meanings may be imported."
      - Flag any notes that add philosophical definitions, classical Greek philosophical concepts, or theological interpretations
      - Flag any notes that import modern lexicon expansions with external meanings
      - Flag any notes that add cultural or historical context beyond basic dictionary definitions
      - Notes should ONLY contain: dictionary meanings, grammatical notes, alternative dictionary translations, basic linguistic information
      
      ================================================================================
      VALIDATION FLAGS
      ================================================================================
      You must return one or more of these flags:
      - OK: Exact text match, complete lexical coverage, LSV translation valid, no LSV violations
      - TEXT_MISMATCH: Text differs from stored source text
      - MISSING_LEXICAL_MEANINGS: At least one token has incomplete lexical range
      - INVALID_MEANING: LSV translation uses a meaning not in word-for-word chart
      - LSV_RULE_VIOLATION: Word-for-word notes contain philosophical/theological imports
    PROMPT
  end

  def build_validation_prompt
    word_for_word_data = @text_content.word_for_word_array
    lsv_notes = @text_content.lsv_notes
    
    <<~PROMPT
      Source: #{@source.name}
      Book: #{@book.std_name} (#{@book.code})
      Chapter: #{@chapter}
      Verse: #{@verse}
      Source Language: #{@source.language.name}
      
      ================================================================================
      VALIDATION TASK
      ================================================================================
      
      Please validate the following against #{@source.name} for #{@book.std_name} #{@chapter}:#{@verse}:
      
      1. SOURCE TEXT (Character-by-character accuracy):
      "#{@text_content.content}"
      
      2. WORD-FOR-WORD TRANSLATION CHART:
      #{word_for_word_data.to_json}
      
      3. LSV LITERAL RECONSTRUCTION:
      "#{@text_content.lsv_literal_reconstruction}"
      
      4. LSV NOTES (if available):
      #{lsv_notes.to_json}
      
      ================================================================================
      VALIDATION REQUIREMENTS
      ================================================================================
      
      Please provide validation in JSON format:
      
      {
        "is_accurate": true/false,
        "accuracy_percentage": 0-100,
        "character_accurate": true/false,
        "lexical_coverage_complete": true/false,
        "lsv_translation_valid": true/false,
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
        "lexical_coverage_issues": [
          {
            "token": "the word/token",
            "issue": "description of missing lexical meanings",
            "missing_meanings": ["meaning1", "meaning2"],
            "completeness_status": "COMPLETE | INCOMPLETE"
          }
        ],
        "lsv_translation_issues": [
          {
            "issue": "description of problem",
            "type": "INVALID_MEANING | EXCEEDS_SOURCE | NOT_FROM_CHART",
            "details": "specific details"
          }
        ],
        "lsv_rule_violations": [
          {
            "token": "the word that has the violation",
            "notes": "the problematic notes text",
            "violation_type": "philosophical/theological/cultural/lexicon_expansion",
            "issue": "description of what violates the LSV rule"
          }
        ],
        "validation_flags": ["OK" | "TEXT_MISMATCH" | "MISSING_LEXICAL_MEANINGS" | "INVALID_MEANING" | "LSV_RULE_VIOLATION"],
        "validation_notes": "Detailed notes about the validation"
      }
      
      ================================================================================
      VALIDATION RULES
      ================================================================================
      
      1. CHARACTER ACCURACY:
      - Compare character-by-character with the source
      - Report 100% accuracy ONLY if every single character matches exactly
      - Include all discrepancies, no matter how small
      - Note any differences in punctuation, diacritics, spacing, or capitalization
      - Set character_accurate to true ONLY if 100% match
      
      2. LEXICAL COVERAGE:
      - For EACH token, verify ALL lexically valid meanings are in base_gloss + secondary_glosses
      - Check completeness field: should be "COMPLETE" only if ALL meanings included
      - If any token is missing valid meanings, add to lexical_coverage_issues
      - Set lexical_coverage_complete to false if ANY token has incomplete coverage
      
      3. LSV TRANSLATION:
      - Verify LSV translation uses ONLY meanings from word-for-word chart
      - Check that no meanings are used that aren't in base_gloss or secondary_glosses
      - Verify LSV translation doesn't exceed source text (no additions)
      - If LSV translation violates these rules, add to lsv_translation_issues
      - Set lsv_translation_valid to false if ANY issues found
      
      4. LSV RULE COMPLIANCE:
      - Review word-for-word notes for each token
      - Check for violations: philosophical definitions, theological interpretations, cultural imports
      - Look for modern lexicon expansions with external meanings
      - Notes should ONLY contain: dictionary meanings, grammatical notes, alternative dictionary translations
      - If violations found, add to lsv_rule_violations and set is_accurate to false
      
      5. OVERALL ACCURACY:
      - Set is_accurate to true ONLY if:
        * character_accurate = true (100% character match)
        * lexical_coverage_complete = true (all meanings included)
        * lsv_translation_valid = true (built from chart only)
        * lsv_rule_violations = [] (no violations)
      - If ANY of these fail, set is_accurate to false
      
      6. VALIDATION FLAGS:
      - Add "OK" if all checks pass
      - Add "TEXT_MISMATCH" if character accuracy < 100%
      - Add "MISSING_LEXICAL_MEANINGS" if any token has incomplete lexical coverage
      - Add "INVALID_MEANING" if LSV translation uses invalid meanings
      - Add "LSV_RULE_VIOLATION" if notes contain philosophical/theological imports
    PROMPT
  end

  def update_validation_fields(result)
    @text_content.update!(
      content_validated_at: Time.current,
      content_validated_by: 'grok-3',
      content_validation_result: {
        is_accurate: result[:is_accurate],
        character_accurate: result[:character_accurate],
        lexical_coverage_complete: result[:lexical_coverage_complete],
        lsv_translation_valid: result[:lsv_translation_valid],
        accuracy_percentage: result[:accuracy_percentage],
        character_accuracy: result[:character_accuracy],
        discrepancies: result[:discrepancies],
        lexical_coverage_issues: result[:lexical_coverage_issues] || [],
        lsv_translation_issues: result[:lsv_translation_issues] || [],
        lsv_rule_violations: result[:lsv_rule_violations] || [],
        validation_flags: result[:validation_flags] || [],
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

  def grok_api_key
    ENV['XAI_API_KEY']
  end

  def call_grok_api(model:, messages:, temperature: 0.0, response_format: nil, max_tokens: nil)
    api_key = grok_api_key
    unless api_key.present?
      raise "Grok API key not found. Please set XAI_API_KEY environment variable"
    end

    uri = URI.parse("https://api.x.ai/v1/chat/completions")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 120
    http.open_timeout = 30

    request = Net::HTTP::Post.new(uri.path)
    request["Authorization"] = "Bearer #{api_key}"
    request["Content-Type"] = "application/json"

    body = {
      model: model,
      messages: messages,
      temperature: temperature
    }
    
    body[:response_format] = response_format if response_format
    body[:max_tokens] = max_tokens if max_tokens

    request.body = body.to_json

    Rails.logger.debug "Grok API request: POST #{uri.path}, model: #{model}"
    
    response = http.request(request)
    
    unless response.is_a?(Net::HTTPSuccess)
      error_body = begin
        JSON.parse(response.body)
      rescue JSON::ParserError
        { error: { message: response.message } }
      end
      error_msg = response.message
      Rails.logger.error "Grok API error (#{response.code}): #{error_msg}"
      Rails.logger.error "Response body: #{response.body[0..500]}"
      raise "Grok API error (#{response.code}): #{error_msg}"
    end

    # Parse the response body - it should be JSON
    parsed_response = begin
      result = JSON.parse(response.body)
      Rails.logger.debug "Parsed response type: #{result.class}"
      result
    rescue JSON::ParserError => e
      Rails.logger.error "Failed to parse Grok API response body: #{e.message}"
      Rails.logger.error "Response body (first 500 chars): #{response.body[0..500]}"
      Rails.logger.error "Response body length: #{response.body.length}"
      raise "Failed to parse Grok API response: #{e.message}. Response body: #{response.body[0..200]}"
    end
    
    # Ensure we return a Hash (not a String or other type)
    if parsed_response.is_a?(String)
      Rails.logger.warn "Grok API returned a string instead of Hash, attempting to parse again"
      parsed_response = JSON.parse(parsed_response)
    end
    
    unless parsed_response.is_a?(Hash)
      Rails.logger.error "Unexpected response type: #{parsed_response.class}"
      Rails.logger.error "Response value (first 500 chars): #{parsed_response.inspect[0..500]}"
      raise "Grok API returned unexpected response type: #{parsed_response.class}. Expected Hash, got #{parsed_response.class}"
    end
    
    Rails.logger.debug "Returning parsed response with keys: #{parsed_response.keys.inspect}"
    parsed_response
  rescue => e
    Rails.logger.error "Grok API error: #{e.class.name}: #{e.message}"
    Rails.logger.error e.backtrace.first(5).join("\n")
    raise e
  end
end

