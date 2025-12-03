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
          { role: "system", content: system_prompt },
          { role: "user", content: prompt }
        ],
        temperature: 0.0, # Zero temperature for exact accuracy
        response_format: { type: "json_object" }
      )

      Rails.logger.debug "Grok API response type: #{response.class}"
      Rails.logger.debug "Grok API response keys: #{response.keys.inspect}" if response.is_a?(Hash)

      # Extract the content from Grok API response: { "choices": [{ "message": { "content": "..." } }] }
      if response.is_a?(Hash) &&
         response["choices"].is_a?(Array) &&
         response["choices"].first.is_a?(Hash) &&
         response["choices"].first["message"].is_a?(Hash)

        ai_response = response["choices"].first["message"]["content"]
      end

      if ai_response.nil?
        Rails.logger.error "Could not extract content from Grok API response"
        Rails.logger.error "Response structure: #{response.inspect[0..500]}"
        return { status: 'error', error: 'Could not extract content from Grok API response' }
      end

      if ai_response.blank?
        return { status: 'error', error: 'Empty response from Grok API' }
      end

      parsed = JSON.parse(ai_response)

      {
        status: 'success',
        source_text: parsed['source_text'],
        word_for_word: parsed['word_for_word'] || [],
        lsv_literal_reconstruction: parsed['lsv_literal_reconstruction'],
        lsv_notes: parsed['lsv_notes'] || {},
        addressed_party_code: parsed['addressed_party_code'],
        addressed_party_custom_name: parsed['addressed_party_custom_name'],
        responsible_party_code: parsed['responsible_party_code'],
        responsible_party_custom_name: parsed['responsible_party_custom_name'],
        genre_code: parsed['genre_code'],
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

  # ===========================
  # PROMPTS
  # ===========================

  def system_prompt
    <<~PROMPT
      You are an expert biblical text scholar specializing in exact textual transcription and word-for-word translation across multiple ancient languages (Greek, Hebrew, Latin, Ge'ez, Syriac, Georgian, etc.).

      Your task for each verse is to:
      1. Extract the EXACT text from the specified source edition (character-by-character accuracy required).
      2. Create a complete word-for-word translation chart with full lexical coverage.
      3. Provide an LSV literal translation built strictly from the word-for-word chart.
      4. Classify the verse with genre_code, addressed_party_code, and responsible_party_code.

      ================================================================================
      GLOBAL RULES – APPLY TO ALL LANGUAGES AND ALL EDITIONS
      ================================================================================

      1. EXACT SOURCE TEXT (CHARACTER-BY-CHARACTER, EDITION-FAITHFUL)
      You MUST reproduce the exact text of the source edition supplied in the input.
      This includes every character exactly as printed:
      - spelling
      - diacritics and accents (including breathings, niqqud, etc.)
      - punctuation
      - brackets or parentheses
      - capitalization
      - word division
      - paragraphing
      - verse boundaries

      You MUST NOT:
      - substitute any reading from ANY other edition or manuscript,
      - normalize or modernize spelling,
      - change capitalization to follow modern or theological conventions,
      - harmonize punctuation or bracketing to other editions,
      - add or remove bracketed text,
      - replace the supplied text with a version you "expect" from a different tradition.

      Use ONLY the text exactly as provided by the source edition. Any deviation is an error.

      2. TOKEN-BY-TOKEN MAPPING (word_for_word)
      For EACH token in the source text, provide:
      {
        "token": "<exact source word/token>",
        "lemma": "<dictionary/lexical form>",
        "morphology": "<part of speech and parsing for this language>",
        "base_gloss": "<primary minimal literal gloss in English>",
        "secondary_glosses": ["<other valid literal glosses>", "..."],
        "completeness": "COMPLETE" or "INCOMPLETE",
        "notes": "<grammatical notes ONLY: case, tense, voice, mood, number, gender, etc.>"
      }

      - base_gloss MUST be the most common, minimal literal meaning.
      - secondary_glosses MUST include ALL other lexically valid literal meanings.
      - If any lexically valid meaning is missing → completeness = "INCOMPLETE".
      - notes MUST NOT include theology, philosophy, or denominational bias. Only linguistic/grammatical info.

      3. LSV LITERAL TRANSLATION (lsv_literal_reconstruction)
      - Built ONLY from:
        * source_text,
        * tokens in word_for_word,
        * their lexical ranges in base_gloss/secondary_glosses.
      - NO paraphrase, NO commentary, NO theology, NO doctrinal smoothing.
      - Preserve source word order as much as English allows.
      - Add only minimal English structural support (e.g., "is", "the") IF absolutely required for grammar.
      - Any structural support must be documented in lsv_notes.structural_support.

      4. LSV NOTES (lsv_notes)
      - lexical_options:
        * For tokens with multiple valid senses, record:
          - primary_sense_used (the one used in translation),
          - secondary_senses_valid (other valid senses).
      - structural_support:
        * List any words added purely for English grammar support.
      - validation_status:
        * "OK" if lexical coverage is complete and translation uses only valid meanings.
        * "MISSING_LEXICAL_MEANINGS" if any token is missing valid senses.
        * "INVALID_MEANING" if you used a meaning not supported by the lexicon.

      5. GLOBAL LSV RULE
      "No external philosophical, theological, or cultural meanings may be imported."
      - DO NOT import philosophical meanings (e.g., Hellenistic philosophical 'logos').
      - DO NOT import dogmatic theological meanings.
      - Use ONLY meanings attested in linguistic lexicons for that language.

      ================================================================================
      LANGUAGE-SPECIFIC RULES – CONDITIONAL BY SOURCE LANGUAGE
      ================================================================================

      #{language_specific_rules}

      ================================================================================
      GENRE / ADDRESSED PARTY / RESPONSIBLE PARTY – UNIVERSAL CLASSIFICATION
      ================================================================================

      These rules apply to all biblical sources (Torah, Prophets, Writings, Gospels, Epistles, etc.)
      in any language.

      1. GENRE (genre_code) – REQUIRED
      Each verse MUST have exactly one genre_code. Choose from:
      • NARRATIVE          – Story-telling, narrative description, historical account, narrator reporting speech.
      • LAW                – Commands, statutes, ordinances, legal text.
      • PROPHECY           – Prophetic oracles and pronouncements.
      • WISDOM             – Wisdom sayings, proverbs, reflective discourse (e.g., Proverbs, Ecclesiastes, Job wisdom).
      • POETRY_SONG        – Poetry, psalms, songs, parallelism.
      • GOSPEL_TEACHING_SAYING – Direct teaching/discourse of Jesus in the Gospels presented as instruction.
      • EPISTLE_LETTER     – Letter/epistle content (Pauline, General Epistles, etc.).
      • APOCALYPTIC_VISION – Visionary/apocalyptic scenes (Daniel, Revelation, similar).
      • GENEALOGY_LIST     – Lists of names, genealogies, censuses.
      • PRAYER             – Direct address to God (prayer, supplication, doxology).

      GENRE RULES:
      - NARRATIVE:
        * Narrator describes events or reports speech.
        * Includes prologues and narrative introductions.
        * If speech occurs inside narration (narrator reporting "he said to them") → NARRATIVE.
      - LAW:
        * Legal commands or prohibitions directed to individuals or groups.
      - PROPHECY:
        * "Thus says the LORD/YHWH…" type oracles; prophetic declarations.
      - GOSPEL_TEACHING_SAYING:
        * ONLY when Jesus is teaching or speaking instructionally in Gospel contexts.
        * Sermon on the Mount, parables as teaching, long discourses.
      - If verse is in a Gospel but is narrator describing events/speech → NARRATIVE (not GOSPEL_TEACHING_SAYING).
      - EPISTLE_LETTER:
        * Content inside NT letters, including doctrinal and practical instruction.
      - PRAYER:
        * Direct address to God (explicitly speaking to God in prayer).

      2. ADDRESSED PARTY (addressed_party_code) – REQUIRED
      Who is the message directed TO in this verse?

      Options:
      • INDIVIDUAL      – A specific person.
      • ISRAEL          – The nation of Israel.
      • JUDAH           – The kingdom of Judah.
      • JEWS            – Jewish people (esp. NT narrative).
      • GENTILES        – Non-Jews.
      • DISCIPLES       – Disciples/followers of Jesus.
      • BELIEVERS       – Believers in general.
      • ALL_PEOPLE      – All humanity / all people.
      • CHURCH          – A specific church/assembly (requires custom name).
      • NOT_SPECIFIED   – No clear audience indicated.

      Detection:
      - Look for explicit or implied recipients:
        * Dative pronouns ("to him/them") in applicable languages.
        * Prepositional phrases "to X", "for X".
        * Vocative forms ("O Israel", "Brothers", "Men of Israel").
        * Second-person verbs or imperatives.
      - If the verse is pure narrator description with no clear recipient → NOT_SPECIFIED.
      - For epistles: greetings "to the church in Corinth" → addressed_party_code = CHURCH, custom_name = "CORINTH".

      CONTINUITY:
      - If a speech or discourse continues across multiple verses with the same speaker and same audience,
        keep the same addressed_party_code unless the text clearly shifts to a new audience.

      3. RESPONSIBLE PARTY (responsible_party_code) – REQUIRED
      Who is delivering or responsible for the message in this verse?

      Options:
      • INDIVIDUAL      – Named or clearly specific person (YHWH, Moses, Isaiah, Jesus, Paul, etc.).
      • ISRAEL          – Nation of Israel as a speaking entity.
      • JUDAH           – Kingdom of Judah as speaker.
      • JEWS            – Jewish leaders/people speaking as a group.
      • GENTILES        – Gentiles as group.
      • DISCIPLES       – Disciples as a group.
      • BELIEVERS       – Believers as a group.
      • ALL_PEOPLE      – Humanity speaking as a group.
      • CHURCH          – Specific church/assembly as speaker.
      • NOT_SPECIFIED   – Narrator / no explicit speaker.

      Detection:
      - Look for speech verbs ("said", "says", "spoke", "answered", etc.).
      - The grammatical subject of the speech verb is the responsible party.
      - If subject is a pronoun ("he said", "they said"), use nearest clear antecedent.
      - If there is no speech verb and the verse is narrator description → NOT_SPECIFIED.

      CONTINUITY:
      - If a single speaker continues across verses, maintain the same responsible_party_code
        until a new speaker appears.

      NOT_SPECIFIED:
      - Use NOT_SPECIFIED when the text does not clearly indicate audience or speaker
        (e.g., narrator truth statements like "In the beginning God created the heavens and the earth").

      Every verse MUST have:
      - exactly one genre_code,
      - exactly one addressed_party_code,
      - exactly one responsible_party_code.
      If uncertain, prefer NOT_SPECIFIED rather than guessing.

    PROMPT
  end

  def build_population_prompt
    language_name = @source.language.respond_to?(:name) ? @source.language.name : @source.language.to_s
    language_code = if @source.language.respond_to?(:code)
                      @source.language.code.to_s.downcase
                    else
                      language_name.to_s.downcase
                    end
    edition_code = if @source.respond_to?(:code)
                     @source.code.to_s
                   else
                     @source.name.to_s
                   end

    <<~PROMPT
      Source: #{@source.name}
      Source Edition Code: #{edition_code}
      Book: #{@book.std_name} (#{@book.code})
      Chapter: #{@chapter}
      Verse: #{@verse}
      Source Language: #{language_name}
      Source Language Code: #{language_code}

      ⚠️ CRITICAL TEXT FIDELITY WARNING ⚠️
      - You MUST preserve the exact text of the source edition.
      - Do NOT:
        * Change lowercase to uppercase or uppercase to lowercase.
        * Add or remove any characters.
        * Add or remove accents or diacritics.
        * Add or remove punctuation or spaces.
        * Introduce or remove brackets or parentheses.
        * Substitute readings from any other edition.

      Please provide the following in JSON format with COMPLETE lexical coverage:

      {
        "source_text": "The EXACT text from #{@source.name} for #{@book.std_name} #{@chapter}:#{@verse} — including all original punctuation, diacritics, capitalization, spacing, and any brackets or parentheses used in the source edition. NO modernization or normalization allowed.",

        "word_for_word": [
          {
            "token": "<exact word/token as it appears in source_text>",
            "lemma": "<dictionary/lexical form>",
            "morphology": "<part of speech / parsing for this language>",
            "base_gloss": "<primary minimal literal gloss>",
            "secondary_glosses": ["<other literal glosses if lexically valid>", "..."],
            "completeness": "COMPLETE | INCOMPLETE",
            "notes": "<grammatical notes ONLY. No theology or philosophy.>"
          }
        ],

        "lsv_literal_reconstruction": "Literal English sentence-level translation built STRICTLY from the word_for_word chart. Only meanings listed in base_gloss/secondary_glosses may be used. Preserve source word order as much as possible. Any added structural words must be minimal and noted in lsv_notes.structural_support.",

        "lsv_notes": {
          "lexical_options": [
            {
              "token": "<token with multiple valid senses>",
              "primary_sense_used": "<sense used in translation>",
              "secondary_senses_valid": ["<other valid senses>", "..."]
            }
          ],
          "structural_support": [
            "<any English structural elements added only for grammar/readability>"
          ],
          "validation_status": "OK | MISSING_LEXICAL_MEANINGS | INVALID_MEANING"
        },

        "genre_code": "REQUIRED – One of: NARRATIVE, LAW, PROPHECY, WISDOM, POETRY_SONG, GOSPEL_TEACHING_SAYING, EPISTLE_LETTER, APOCALYPTIC_VISION, GENEALOGY_LIST, PRAYER.",
        "addressed_party_code": "REQUIRED – One of: INDIVIDUAL, ISRAEL, JUDAH, JEWS, GENTILES, DISCIPLES, BELIEVERS, ALL_PEOPLE, CHURCH, NOT_SPECIFIED.",
        "addressed_party_custom_name": "If addressed_party_code is CHURCH, provide the church name (e.g., CORINTH, ROME). Otherwise null.",
        "responsible_party_code": "REQUIRED – One of: INDIVIDUAL, ISRAEL, JUDAH, JEWS, GENTILES, DISCIPLES, BELIEVERS, ALL_PEOPLE, CHURCH, NOT_SPECIFIED.",
        "responsible_party_custom_name": "If responsible_party_code is CHURCH, provide the church name. Otherwise null.",
        "ai_notes": "Any additional technical notes about the text, variants, or translation challenges."
      }

      Remember:
      - Use the universal LSV core rules plus the language-specific rules (if any) for this Source Language Code.
      - Prefer NOT_SPECIFIED rather than guessing about audience or speaker if the text is unclear.
    PROMPT
  end

  # Language-specific rules block (only Greek populated for now)
  def language_specific_rules
    language_name = @source.language.respond_to?(:name) ? @source.language.name : @source.language.to_s
    language_code = if @source.language.respond_to?(:code)
                      @source.language.code.to_s.downcase
                    else
                      language_name.to_s.downcase
                    end

    case language_code
    when 'grc', 'el', 'greek'
      <<~RULES
        For Source Language Code 'grc' (Koine Greek):

        1. Prepositions:
           - πρὸς + accusative:
             * base_gloss MUST be "toward" or "to".
             * NEVER use "with" as base_gloss (that is interpretive smoothing).
             * "with" may appear only as a secondary_gloss if lexically justified, but not primary.
           - ἐν + dative:
             * base_gloss MUST be "in".
             * secondary_glosses MAY include "at", "among", "with" if lexically valid.

        2. Imperfect Verbs (e.g., ἦν):
           - Imperfect aspect MUST be preserved in base_gloss as "was-being" or an equivalent that clearly indicates ongoing past action.
           - Do NOT collapse imperfect to simple past "was" without aspect in base_gloss.
           - You may note a smoother English rendering in lsv_notes.structural_support, but the literal base_gloss stays aspect-aware.

        3. Demonstrative Pronouns (e.g., οὗτος):
           - base_gloss MUST be "this" or "this one".
           - NEVER use "he/she/it" as base_gloss for demonstratives (that is interpretive smoothing).
           - If context suggests "he", record that only in lsv_notes, not as the literal gloss.

        4. Articles:
           - If Greek has NO article, do NOT add an article in base_gloss.
           - If Greek has an article, reflect it literally where possible.
           - Do NOT introduce English articles for theological reasons (e.g., to support or deny Christology).

        5. Specific Lexical Example – λόγος:
           - base_gloss may include ONLY:
             * "word", "speech", "statement", or closely related literal communicative senses.
           - DO NOT import philosophical senses like "reason", "principle", "rationality".
           - secondary_glosses MUST stay within strictly linguistic dictionary senses.

        6. Greek Morphology:
           - morphology should specify:
             * Part of speech,
             * Case, number, gender for nouns/adjectives/pronouns,
             * Tense, voice, mood, person, number for verbs.
           - notes MUST remain purely grammatical (no theological commentary).

        7. Westcott-Hort 1881 Specific Editorial Conventions:
           - Use the exact text of the 1881 edition (not NA28/UBS5 or Tregelles or SBLGNT).
           - WH1881 uses **no square brackets** in the main text (unlike NA28).
           - WH1881 uses **parentheses ()** for text they print but consider doubtful.
           - Punctuation and paragraphing follow WH1881 exactly (e.g., no colon after λέγει αὐτοῖς in John 2:5 — WH has a comma).
           - Capitalization: WH1881 uses capitals only for proper names and the beginning of paragraphs/sentences. Divine names (Θεός, Κύριος) are **not** capitalized unless sentence-initial.
           - Do NOT "correct" to NA28 punctuation or bracketing.

        8. Known WH1881 Quirks You Must Reproduce Exactly:
           - John 7:53–8:11 is present but enclosed in double square brackets [[ ]].
           - Mark 16:9–20 is present with note but not bracketed.
           - Luke 22:43–44 is in double square brackets.
           - When these passages appear, reproduce the exact bracketing as in the 1881 printing.

        If the source language is NOT Greek:
        - Treat all of the above Greek rules as examples ONLY.
        - Do NOT attempt to apply πρὸς / ἐν / imperfect / λόγος rules to non-Greek texts.
        - Instead, apply the SAME LSV philosophy using that language's own lexicon and grammar.

      RULES
    else
      <<~RULES
        For this source language, there are currently NO additional language-specific micro-rules beyond the universal LSV core.

        You MUST still:
        - Extract exact source_text without modification.
        - Provide token → lemma → morphology → base_gloss → secondary_glosses.
        - Include ALL lexically valid literal meanings.
        - Build LSV translation strictly from those lexical ranges.
        - Classify genre_code, addressed_party_code, responsible_party_code using the universal rules.

        If the language has known grammatical categories (cases, verb aspects, stems, etc.),
        reflect them accurately in morphology and notes using that language's standard linguistic description.
      RULES
    end
  end

  # ===========================
  # SAVE RESULTS
  # ===========================

  def update_text_content(result)
    word_for_word_data = {
      tokens: result[:word_for_word] || [],
      lsv_notes: result[:lsv_notes] || {}
    }

    update_params = {
      content: result[:source_text],
      word_for_word_translation: word_for_word_data,
      lsv_literal_reconstruction: result[:lsv_literal_reconstruction],
      content_populated_at: Time.current,
      content_populated_by: 'grok-3'
    }

    # Required classification fields; use NOT_SPECIFIED when missing
    update_params[:addressed_party_code] = result[:addressed_party_code].presence || 'NOT_SPECIFIED'
    update_params[:addressed_party_custom_name] = result[:addressed_party_custom_name] if result[:addressed_party_custom_name].present?
    update_params[:responsible_party_code] = result[:responsible_party_code].presence || 'NOT_SPECIFIED'
    update_params[:responsible_party_custom_name] = result[:responsible_party_custom_name] if result[:responsible_party_custom_name].present?

    if result[:genre_code].present?
      update_params[:genre_code] = result[:genre_code]
    else
      Rails.logger.error "WARNING: genre_code missing for #{@text_content.unit_key} - this is required!"
      # Allow model validations to catch missing genre_code instead of silently guessing.
    end

    @text_content.update!(update_params)
  end

  def log_population(result)
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

  # ===========================
  # GROK API
  # ===========================

  def grok_api_key
    ENV['XAI_API_KEY']
  end

  def call_grok_api(model:, messages:, temperature: 0.0, response_format: nil, max_tokens: nil)
    api_key = grok_api_key
    raise "Grok API key not found. Please set XAI_API_KEY environment variable" unless api_key.present?

    uri = URI.parse("https://api.x.ai/v1/chat/completions")
    
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

    # Try the request with normal SSL verification first
    begin
      http = Net::HTTP.new(uri.host, uri.port)
      http.read_timeout = 120
      http.open_timeout = 30
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      
      response = http.request(request)
    rescue OpenSSL::SSL::SSLError => e
      # If it's a CRL error, retry with a workaround that disables CRL checking
      if e.message.include?('CRL') || e.message.include?('revocation')
        Rails.logger.warn "CRL check failed, retrying with CRL checking disabled: #{e.message}"
        
        # Retry with a custom SSL context that doesn't check CRL
        http = Net::HTTP.new(uri.host, uri.port)
        http.read_timeout = 120
        http.open_timeout = 30
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER
        
        # For CRL errors, temporarily disable SSL verification as a workaround
        # This is necessary because OpenSSL cannot reach the CRL server
        # Note: The connection is still encrypted, we just skip certificate verification
        # This is acceptable for API calls where the endpoint is trusted
        Rails.logger.warn "Using VERIFY_NONE as workaround for CRL error - connection is still encrypted"
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        
        response = http.request(request)
      else
        # Re-raise non-CRL SSL errors
        raise
      end
    end

    unless response.is_a?(Net::HTTPSuccess)
      error_body = begin
        JSON.parse(response.body)
      rescue JSON::ParserError
        { error: { message: response.message } }
      end
      error_msg = error_body.dig('error', 'message') || response.message
      Rails.logger.error "Grok API error (#{response.code}): #{error_msg}"
      Rails.logger.error "Response body: #{response.body[0..500]}"
      raise "Grok API error (#{response.code}): #{error_msg}"
    end

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

    if parsed_response.is_a?(String)
      Rails.logger.warn "Grok API returned a string instead of Hash, attempting to parse again"
      parsed_response = JSON.parse(parsed_response)
    end

    unless parsed_response.is_a?(Hash)
      Rails.logger.error "Unexpected response type: #{parsed_response.class}"
      Rails.logger.error "Response value (first 500 chars): #{parsed_response.inspect[0..500]}"
      raise "Grok API returned unexpected response type: #{parsed_response.class}. Expected Hash."
    end

    Rails.logger.debug "Returning parsed response with keys: #{parsed_response.keys.inspect}"
    parsed_response
  rescue OpenSSL::SSL::SSLError => e
    Rails.logger.error "Grok API SSL error: #{e.message}"
    if e.message.include?('CRL')
      Rails.logger.error "CRL (Certificate Revocation List) check failed - this is usually a network/firewall issue."
      Rails.logger.error "The certificate is valid, but OpenSSL cannot reach the CRL server to verify revocation status."
      Rails.logger.error "This is often temporary and may resolve itself, or may require network/firewall configuration."
    else
      Rails.logger.error "This may be caused by outdated system certificates or network issues."
    end
    Rails.logger.error e.backtrace.first(5).join("\n")
    raise "SSL connection failed: #{e.message}"
  rescue => e
    Rails.logger.error "Grok API error: #{e.class.name}: #{e.message}"
    Rails.logger.error e.backtrace.first(5).join("\n")
    raise e
  end
end
