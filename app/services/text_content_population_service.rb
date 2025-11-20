require 'net/http'
require 'json'
require 'uri'

class TextContentPopulationService
  def initialize(text_content)
    @text_content = text_content
    @source = text_content.source
    @book = text_content.book
    @chapter = text_content.unit_group
    @verse = text_content.unit
  end

  def populate_content_fields(force: false)
    Rails.logger.info "Populating content fields for #{@text_content.unit_key}"
    
    # Check if already populated (unless force is true)
    unless force
      if @text_content.content_populated? && @text_content.content.present?
        Rails.logger.info "Content already populated at #{@text_content.content_populated_at}. Use force: true to overwrite."
        return {
          status: 'already_populated',
          message: "Content already populated at #{@text_content.content_populated_at}",
          content_populated_at: @text_content.content_populated_at
        }
      end
    end
    
    # Fetch exact source text and word-for-word translation
    result = fetch_source_content
    
    if result[:status] == 'success'
      update_text_content(result)
      log_population(result)
      { status: 'success', data: result, overwrote: force && @text_content.content_populated? }
    else
      Rails.logger.error "Failed to populate content: #{result[:error]}"
      { status: 'error', error: result[:error] }
    end
  rescue => e
    Rails.logger.error "Error in TextContentPopulationService: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    { status: 'error', error: e.message }
  end

  private

  def fetch_source_content
    max_retries = 3
    retry_count = 0
    ai_response = nil
    
    begin
      prompt = build_population_prompt

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
        temperature: 0.0, # Zero temperature for exact accuracy
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
        return { status: 'error', error: 'Could not extract content from Grok API response' }
      end
      
      if ai_response.blank?
        return { status: 'error', error: 'Empty response from Grok API' }
      end

      # Parse JSON response
      parsed = JSON.parse(ai_response)
      
      {
        status: 'success',
        source_text: parsed['source_text'],
        word_for_word: parsed['word_for_word'] || [],
        lsv_literal_reconstruction: parsed['lsv_literal_reconstruction'],
        ai_notes: parsed['ai_notes'],
        raw_response: ai_response
      }
    rescue JSON::ParserError => e
      Rails.logger.error "Failed to parse Grok API response: #{e.message}"
      Rails.logger.error "Raw response: #{ai_response || 'N/A'}"
      { status: 'error', error: "Failed to parse Grok API response: #{e.message}" }
    rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ETIMEDOUT => e
      retry_count += 1
      if retry_count < max_retries
        wait_time = retry_count * 2 # Exponential backoff: 2s, 4s, 6s
        Rails.logger.warn "Timeout error (attempt #{retry_count}/#{max_retries}): #{e.message}. Retrying in #{wait_time}s..."
        sleep wait_time
        retry
      else
        Rails.logger.error "Max retries reached. Error: #{e.message}"
        { status: 'error', error: "Network timeout after #{max_retries} attempts: #{e.message}" }
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
        { status: 'error', error: "Network connection failed after #{max_retries} attempts: #{e.message}. Please check your internet connection." }
      end
    rescue => e
      Rails.logger.error "Error fetching source content: #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")
      { status: 'error', error: "#{e.class.name}: #{e.message}" }
    end
  end

  def system_prompt
    <<~PROMPT
      You are an expert biblical text scholar specializing in exact textual transcription and word-for-word translation.
      
      Your task is to:
      1. Extract the EXACT text from the specified source (character-by-character accuracy required)
      2. Create a word-for-word translation table with three columns:
         - Source language word (exact as in source)
         - English translation (dictionary meaning, not contextual interpretation)
         - AI translation comments (explain word choice, alternative meanings, grammatical notes)
      3. Provide a literal reconstruction that preserves the source language structure while being readable in English
      
      CRITICAL REQUIREMENTS:
      - The source text must be 100% exactly as it appears in the source, including all punctuation, diacritics, and spacing
      - Do not modify, modernize, or "correct" the source text
      - Word-for-word translation should be dictionary-based, not contextually interpreted
      - Include all alternative meanings when a word has multiple possible translations
      - Preserve the exact word order from the source
      
      LSV RULE - STRICTLY ENFORCED:
      "No external philosophical, theological, or cultural meanings may be imported."
      - Do NOT add philosophical definitions, classical Greek philosophical concepts, or theological interpretations
      - Do NOT add modern lexicon expansions that import external meanings
      - Do NOT add cultural or historical context that goes beyond basic dictionary definitions
      - Comments should ONLY explain:
        * Dictionary-based word meanings
        * Grammatical notes (case, tense, voice, etc.)
        * Alternative dictionary translations
        * Basic linguistic information
      - If a word has multiple dictionary meanings, list them, but do NOT import philosophical or theological interpretations
    PROMPT
  end

  def build_population_prompt
    <<~PROMPT
      Source: #{@source.name}
      Book: #{@book.std_name} (#{@book.code})
      Chapter: #{@chapter}
      Verse: #{@verse}
      Source Language: #{@source.language.name}
      
      Please provide the following in JSON format:
      
      {
        "source_text": "The EXACT text from #{@source.name} for #{@book.std_name} #{@chapter}:#{@verse}, character-by-character accurate",
        "word_for_word": [
          {
            "word": "exact word from source",
            "literal_meaning": "dictionary meaning",
            "confidence": 100,
            "notes": "explanation of word choice, alternatives, grammatical notes"
          }
        ],
        "lsv_literal_reconstruction": "Literal English reconstruction preserving source structure",
        "ai_notes": "Any additional notes about the text, variants, or translation challenges"
      }
      
      IMPORTANT:
      - Extract the text EXACTLY as it appears in #{@source.name}
      - Do not add, remove, or modify any characters
      - Include all punctuation, diacritics, and spacing exactly as in the source
      - For word_for_word array, preserve the exact order of words from the source
      - English translations should be dictionary-based, not contextually interpreted
      - Use "word" for source language word, "literal_meaning" for English translation, "confidence" (1-100), and "notes" for AI comments
      
      LSV RULE - CRITICAL:
      In the "notes" field for each word, you MUST:
      - Only provide dictionary-based meanings and grammatical notes
      - Do NOT add philosophical definitions, theological interpretations, or cultural meanings
      - Do NOT import external philosophical concepts (e.g., "classical Greek philosophy", "Platonic concepts")
      - Do NOT add theological interpretations beyond basic dictionary meanings
      - Do NOT expand with modern lexicon meanings that import external philosophical/theological concepts
      - Focus ONLY on: grammatical information, dictionary definitions, alternative dictionary translations
      
      Example of CORRECT notes:
      "Dative case, meaning 'at' or 'in'. Can also mean 'with' in some contexts."
      
      Example of INCORRECT notes (DO NOT DO THIS):
      "In classical Greek philosophy, this word carries deep philosophical meaning related to..."
      "Can also mean 'reason' or 'principle'" (this imports philosophical concepts)
      "In theological contexts, this word means..." (this imports theological interpretations)
      
      SPECIFIC WORD EXAMPLES:
      - For λόγος: Use ONLY "word" or "speech" or "statement" - DO NOT add "reason" or "principle" as these are philosophical imports
      - For any word: Only use dictionary meanings that are purely linguistic, not philosophical/theological extensions
    PROMPT
  end

  def update_text_content(result)
    @text_content.update!(
      content: result[:source_text],
      word_for_word_translation: result[:word_for_word],
      lsv_literal_reconstruction: result[:lsv_literal_reconstruction],
      content_populated_at: Time.current,
      content_populated_by: 'grok-3'
    )
  end

  def log_population(result)
    # Log the API request/response
    TextContentApiLog.create!(
      text_content_id: @text_content.id,
      api_endpoint: 'populate_content',
      request_data: {
        source: @source.name,
        book: @book.std_name,
        chapter: @chapter,
        verse: @verse
      },
      response_data: {
        source_text: result[:source_text],
        word_for_word_count: result[:word_for_word]&.count || 0,
        lsv_literal_reconstruction: result[:lsv_literal_reconstruction],
        ai_notes: result[:ai_notes]
      },
      raw_response: result[:raw_response],
      status: 'success'
    )
  rescue => e
    Rails.logger.error "Failed to log population: #{e.message}"
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

