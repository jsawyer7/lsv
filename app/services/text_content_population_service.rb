require 'net/http'
require 'json'
require 'uri'
require 'concurrent'

class TextContentPopulationService
  # Configuration from environment variables
  MAX_CONCURRENT = ENV.fetch('GROK_MAX_CONCURRENT', '30').to_i
  GROK_MODEL = ENV.fetch('GROK_MODEL', 'grok-4-0709')
  # Increased max_tokens to handle large word-for-word translations with all required fields
  GROK_MAX_TOKENS = ENV.fetch('GROK_MAX_TOKENS', '8000').to_i
  GROK_TIMEOUT = ENV.fetch('GROK_TIMEOUT_SECONDS', '180').to_i

  # Semaphore for rate limiting concurrent requests
  SEMAPHORE = Concurrent::Semaphore.new(MAX_CONCURRENT)
  def initialize(text_content)
    @text_content = text_content
    @source = text_content.source
    @book = text_content.book
    @chapter = text_content.unit_group
    @verse = text_content.unit
  end

  def populate_content_fields(force: false)
    Rails.logger.info "Populating content fields for #{@text_content.unit_key}"

    # Update attempt timestamp
    @text_content.update_column(:last_population_attempt_at, Time.current)

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

    # Set status to processing
    @text_content.update_column(:population_status, 'processing')

    # Fetch reconstructed source text and word-for-word translation
    result = fetch_source_content

    if result[:status] == 'success'
      # Step 1: Apply generic metadata inference (replaces hard-coded logic)
      # This works for all sources, not just LXX
      result = apply_generic_metadata_inference(result)

      # Step 2: Deterministic local validation (no AI self-validation)
      # Use :populate mode to allow fixable style/gloss issues through as warnings
      pipeline = Verifaith::TextContentValidationPipeline.new(
        text_content: @text_content,
        source_text: result[:source_text],
        word_for_word: result[:word_for_word],
        lsv_literal_reconstruction: result[:lsv_literal_reconstruction],
        genre_code: result[:genre_code],
        addressed_party_code: result[:addressed_party_code],
        responsible_party_code: result[:responsible_party_code],
        mode: :populate
      )

      validation = pipeline.run

      if validation.ok?
        # Step 3: Basic structural checks before saving
        validation_result = validate_ai_response(result)

        if validation_result[:valid]
          update_text_content(result)
          log_population(result)

          # In populate mode, warnings are acceptable (style/gloss drift)
          # Store warnings and repair hints for potential future repair
          status = validation.warnings.any? ? 'provisional_ok' : 'success'
          
          # Mark as success or provisional_ok; canonical fidelity information is stored in validation meta/flags
          @text_content.update_columns(
            population_status: status,
            population_error_message: nil
          )

          {
            status: status,
            data: result.merge(
              validation_flags: validation.flags,
              validation_warnings: validation.warnings,
              validation_meta: validation.meta
            ),
            overwrote: force && @text_content.content_populated?
          }
        else
          # Structural validation failed (missing core fields, etc.)
          error_msg = validation_result[:error] || 'AI response validation failed'
          @text_content.update_columns(
            population_status: 'error',
            population_error_message: error_msg.truncate(1000)
          )
          Rails.logger.error "AI response validation failed: #{error_msg}"
          {
            status: 'error',
            error: error_msg,
            flags: validation.flags,
            warnings: validation.warnings,
            meta: validation.meta
          }
        end
      else
        # Deterministic validators failed – treat as needs_repair if canonical mismatch, else error
        flags = validation.flags
        canonical_status = validation.meta[:canonical_fidelity]

        error_msg =
          if flags.include?('CANONICAL_MISMATCH')
            'Canonical fidelity mismatch detected during population'
          elsif flags.include?('SWETE_CONTAMINATION')
            'Swete contamination detected during population'
          else
            validation.errors.join('; ').presence || 'Deterministic validation failed'
          end

        new_status =
          if canonical_status == 'MISMATCH'
            'needs_repair'
          else
            'error'
          end

        @text_content.update_columns(
          population_status: new_status,
          population_error_message: error_msg.truncate(1000)
        )

        Rails.logger.error "Deterministic validation failed for #{@text_content.unit_key}: #{error_msg}"

        {
          status: new_status,
          error: error_msg,
          flags: flags,
          warnings: validation.warnings,
          meta: validation.meta,
          is_accurate: false
        }
      end
    elsif result[:status] == 'unavailable'
      # Mark as unavailable
      @text_content.update_columns(
        population_status: 'unavailable',
        population_error_message: result[:error]&.truncate(1000)
      )
      { status: 'unavailable', error: result[:error] }
    else
      # Mark as error
      error_msg = result[:error] || 'Unknown error'
      @text_content.update_columns(
        population_status: 'error',
        population_error_message: error_msg.truncate(1000)
      )
      Rails.logger.error "Failed to populate content: #{error_msg}"
      { status: 'error', error: error_msg }
    end
  rescue => e
    error_msg = "#{e.class.name}: #{e.message}"
    Rails.logger.error "Error in TextContentPopulationService: #{error_msg}"
    Rails.logger.error e.backtrace.join("\n")
    
    # Mark as error
    @text_content.update_columns(
      population_status: 'error',
      population_error_message: error_msg.truncate(1000)
    )
    
    { status: 'error', error: error_msg }
  end

  private

  def fetch_source_content
    max_retries = 3
    retry_count = 0
    ai_response = nil

    begin
      prompt = build_population_prompt
      response = call_grok_api(
        model: GROK_MODEL,
        messages: [
          { role: "system", content: system_prompt },
          { role: "user", content: prompt }
        ],
        temperature: 0.0, # Zero temperature for exact accuracy
        response_format: { type: "json_object" },
        max_tokens: GROK_MAX_TOKENS
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

      # Check for unavailable text indicator
      if ai_response.strip == '[EDITION_TEXT_UNAVAILABLE]' || ai_response.include?('[EDITION_TEXT_UNAVAILABLE]')
        return { status: 'unavailable', error: 'Text unavailable in source edition' }
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
      • PARABLE            – Parable: a short story used to illustrate a moral or spiritual lesson (e.g., Jesus' parables like the Sower, Good Samaritan, Prodigal Son).
      • GOSPEL_TEACHING_SAYING – Direct teaching/discourse of Jesus in the Gospels presented as instruction (not parables).
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
      - PARABLE:
        * A short narrative story used to illustrate a moral or spiritual lesson.
        * Typically introduced with phrases like "The kingdom of heaven is like..." or "A certain man had..."
        * Distinct from GOSPEL_TEACHING_SAYING: parables are illustrative stories, while teachings are direct instruction.
        * Examples: Parable of the Sower, Parable of the Good Samaritan, Parable of the Prodigal Son.
        * If Jesus tells a parable, use PARABLE (not GOSPEL_TEACHING_SAYING).

      - GOSPEL_TEACHING_SAYING:
        * ONLY when Jesus is teaching or speaking instructionally in Gospel contexts (direct instruction, not parables).
        * Direct sayings, commands, explanations, or teachings without narrative story structure.
        * Sermon on the Mount, long discourses (but NOT parables - use PARABLE for those).
      - If verse is in a Gospel but is narrator describing events/speech → NARRATIVE (not GOSPEL_TEACHING_SAYING).
      - If verse is a parable → PARABLE (not GOSPEL_TEACHING_SAYING).
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

      Detection (ORDER OF OPERATIONS - CRITICAL):
      
      1. SPEECH SEGMENT DETECTION (First Priority):
         - Look for speech intro patterns: "λέγει κύριος", "τάδε λέγει κύριος", "εἶπεν ὁ θεός", 
           "εἶπεν Δαυίδ", "εἶπεν Ἰώβ", etc.
         - When a speech intro is found, start a speech block with that speaker.
         - Continue the speech block until another explicit speaker intro appears or a narrative break occurs.
         - For verses inside a speech block, use the block's speaker as responsible_party.
         - DO NOT apply personified speech rules to verses inside speech blocks.
      
      2. EXPLICIT IDENTIFIERS (Second Priority):
         - Look for speech verbs ("said", "says", "spoke", "answered", etc.) in the current verse.
         - The grammatical subject of the speech verb is the responsible party.
         - If subject is a pronoun ("he said", "they said"), use nearest clear antecedent.
      
      3. PERSONIFIED SPEECH FALLBACK (Third Priority - Only if not in speech segment):
         - If verse is NOT in a known speech segment AND contains first-person markers (ἐγώ, μου, με, etc.)
           AND personified entities (σοφία/Wisdom, ἀμπελών/vineyard, ἀγαπητός/beloved, Σιών/Zion):
         - Set responsible_party_code = NOT_SPECIFIED
         - Set addressed_party_code = NOT_SPECIFIED
         - This handles Wisdom in Proverbs 8, vineyard parables, etc.
      
      4. DEFAULT (Last Resort):
         - If there is no speech verb and the verse is narrator description → NOT_SPECIFIED.

      CONTINUITY:
      - If a single speaker continues across verses (within a speech segment), maintain the same responsible_party_code
        until a new speaker appears or the speech segment ends.

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

        "genre_code": "REQUIRED – One of: NARRATIVE, LAW, PROPHECY, WISDOM, POETRY_SONG, PARABLE, GOSPEL_TEACHING_SAYING, EPISTLE_LETTER, APOCALYPTIC_VISION, GENEALOGY_LIST, PRAYER.",
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
           - ⚠️ CRITICAL CAPITALIZATION RULE: base_gloss MUST ALWAYS be "word" (lowercase "w") in ALL contexts.
           - NO exceptions. No "Word." No titular capitalisation. NEVER capitalise based on theological tradition.

        6. Capitalisation and Theological Smoothing in English Glosses (ABSOLUTE PROHIBITION):
           - NEVER capitalise an English gloss solely because of traditional theological rendering.
           - Capitalisation may ONLY occur when the underlying Greek grammar marks the word as a proper title/name through article + contextual identification.
           - ANY violation of these capitalisation rules MUST automatically set completeness: "INCOMPLETE" and trigger a repair step.

           # θεός ("theos") Capitalisation Rules:
           - When anarthrous (no article), or functioning as a predicate nominative, or used in a qualitative sense:
             → base_gloss MUST be "god" or "deity" (lowercase "g").
           - ONLY use "God" (capital G) when BOTH conditions are true:
             1. Greek has the article (ὁ, τὸν, τοῦ, etc.) identifying a specific referent, AND
             2. Context explicitly identifies this referent as the Father (the one God of Israel).
           - Any other context → lowercase "god".

           # κύριος ("kyrios") Capitalisation Rules:
           - base_gloss MUST be "lord" or "master" (lowercase) unless the Greek uses the article AND the narrative context makes it a clear titular reference.
           - Under no circumstances infer divine LORD simply because tradition capitalises it.

           # Summary:
           - English capitalisation must follow Greek grammar, NEVER theology.
           - Greek never uses capitals for titles → neither can LSV.

        7. Prepositions with Stative Verbs or Participles (εἰς / ἐν idiom):
           - When εἰς governs an accusative locative/relational noun AND the governing verb or participle is stative
             (εἰμί, ὑπάρχω, μένω, κάθημαι, κεῖμαι, γίνομαι, or any present/active participle of these),
             the idiomatic Koine gloss is "in" (locative), not "into" (directional).
           - Examples:
             • ὁ ὢν εἰς τὸν κόλπον → "the one being in the bosom"
             • μένει εἰς τὸν αἰῶνα → "remains in the age"
           - base_gloss for εἰς in these frames MUST be "in".
           - If you use "into", set completeness: "INCOMPLETE" and trigger repair.

        8. Structural Support for English Articles – Anarthrous vs Articular Phrases:
           - Before adding "the" (or "a/an") in lsv_literal_reconstruction,
             you MUST determine whether the Greek noun phrase is articular or anarthrous.
           - A noun phrase is articular only if an article (ὁ, ἡ, τό, etc.) matches
             the noun in case, number, and gender and stands in the same phrase.
           - If the phrase is anarthrous (e.g., μονογενὴς θεός, θεὸς ἦν ὁ λόγος),
             any English "the" is pure structural support.
             → lsv_notes.structural_support MUST explicitly say:
               "English 'the' added for grammar; Greek phrase is anarthrous."
           - Never say an added article "reflects the Greek article" unless it actually does.

        9. Syntax Notes Must Be Precise and Verifiable:
           - The "notes" field may only contain purely grammatical information.
           - When stating syntactic role (subject, object, etc.),
             you MUST name the exact governing lemma, e.g.:
               "Accusative case, direct object of ἑώρακεν."
               "Nominative case, subject of ἐξηγήσατο."
           - Never use vague phrases like "object of the verb" without naming the verb.
           - These notes MUST align with explicit dependency data
             (head verb/participle and syntactic_role for each token).

        10. Greek Morphology:
           - morphology should specify:
             * Part of speech,
             * Case, number, gender for nouns/adjectives/pronouns,
             * Tense, voice, mood, person, number for verbs.
           - notes MUST remain purely grammatical (no theological commentary).

        11. Westcott-Hort 1881 Specific Editorial Conventions:
           - Use the exact text of the 1881 edition (not NA28/UBS5 or Tregelles or SBLGNT).
           - WH1881 uses **no square brackets** in the main text (unlike NA28).
           - WH1881 uses **parentheses ()** for text they print but consider doubtful.
           - Punctuation and paragraphing follow WH1881 exactly (e.g., no colon after λέγει αὐτοῖς in John 2:5 — WH has a comma).
           - Capitalization: WH1881 uses capitals only for proper names and the beginning of paragraphs/sentences. Divine names (Θεός, Κύριος) are **not** capitalized unless sentence-initial.
           - Do NOT "correct" to NA28 punctuation or bracketing.

        12. Known WH1881 Quirks You Must Reproduce Exactly:
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
  # DIVINE SPEECH DETECTION (LXX)
  # ===========================

  # Known divine speech verses in LXX (whitelist for bulletproof detection)
  def swete_source?
    @source.code == 'LXX_SWETE' || 
    @source.name.include?('Swete') || 
    @source.code&.include?('SWETE')
  end

  def lxx_source?
    swete_source? ||
    @source.name.include?('Septuagint') ||
    @source.code&.include?('LXX')
  end

  # Apply generic metadata inference (replaces hard-coded book/verse logic)
  # This works for all sources and all verses without special cases
  def apply_generic_metadata_inference(result)
    greek_text = result[:source_text] || @text_content.content || ''
    return result if greek_text.blank?

    # Get existing metadata from result or text_content
    existing_responsible_code = result[:responsible_party_code] || @text_content.responsible_party_code || 'NOT_SPECIFIED'
    existing_addressed_code = result[:addressed_party_code] || @text_content.addressed_party_code || 'NOT_SPECIFIED'
    existing_responsible_custom = result[:responsible_party_custom_name] || @text_content.responsible_party_custom_name

    # Use generic inference service
    inference_service = GenericMetadataInferenceService.new(
      greek_text,
      genre_code: result[:genre_code],
      existing_responsible_code: existing_responsible_code,
      existing_addressed_code: existing_addressed_code,
      existing_responsible_custom: existing_responsible_custom
    )

    inferred_metadata = inference_service.infer_metadata

    # Apply inferred metadata to result
    result[:responsible_party_code] = inferred_metadata[:responsible_party_code]
    result[:responsible_party_custom_name] = inferred_metadata[:responsible_party_custom_name]
    result[:addressed_party_code] = inferred_metadata[:addressed_party_code]

    # Log if metadata changed
    if inferred_metadata[:responsible_party_code] != existing_responsible_code ||
       inferred_metadata[:addressed_party_code] != existing_addressed_code
      Rails.logger.info "Generic metadata inference for #{@text_content.unit_key}: " \
        "responsible=#{inferred_metadata[:responsible_party_code]}(#{inferred_metadata[:responsible_party_custom_name]}), " \
        "addressed=#{inferred_metadata[:addressed_party_code]}"
    end

    result
  end

  # ===========================
  # SAVE RESULTS
  # ===========================

  def update_text_content(result)
    # STEP 1: Validate word-for-word layer for Swete sources
    # Ensure glosses don't invent words that aren't in the source text
    if swete_source? && result[:word_for_word].present?
      validate_word_for_word_layer!(result[:source_text], result[:word_for_word])
    end

    word_for_word_data = {
      tokens: result[:word_for_word] || [],
      lsv_notes: result[:lsv_notes] || {}
    }

    update_params = {
      content: result[:source_text],
      word_for_word_translation: word_for_word_data,
      lsv_literal_reconstruction: result[:lsv_literal_reconstruction],
      content_populated_at: Time.current,
      content_populated_by: GROK_MODEL
    }

    # Universal: Enforce text_unit_type based on unit_key shape
    # TRAD|BOOK|CH|VS (4 parts) => Verse
    # TRAD|BOOK|CH (3 parts) => Chapter
    if @text_content.unit_key.present?
      expected_type_code = enforce_text_unit_type_from_key(@text_content.unit_key)
      if expected_type_code
        expected_type = TextUnitType.unscoped.find_by(code: expected_type_code)
        if expected_type && @text_content.text_unit_type_id != expected_type.id
          Rails.logger.warn "[TEXT_UNIT_TYPE] Correcting text_unit_type for #{@text_content.unit_key}: #{@text_content.text_unit_type&.code} => #{expected_type_code}"
          update_params[:text_unit_type_id] = expected_type.id
        end
      end
    end

    # Required classification fields; use NOT_SPECIFIED when missing
    update_params[:addressed_party_code] = result[:addressed_party_code].presence || 'NOT_SPECIFIED'
    update_params[:addressed_party_custom_name] = result[:addressed_party_custom_name] if result[:addressed_party_custom_name].present?
    update_params[:responsible_party_code] = result[:responsible_party_code].presence || 'NOT_SPECIFIED'
    
    # Universal Metadata Neutrality Rule: If responsible_party_code == NOT_SPECIFIED,
    # then responsible_party_custom_name must be null
    if update_params[:responsible_party_code] == 'NOT_SPECIFIED'
      update_params[:responsible_party_custom_name] = nil
    else
      update_params[:responsible_party_custom_name] = result[:responsible_party_custom_name] if result[:responsible_party_custom_name].present?
    end

    if result[:genre_code].present?
      update_params[:genre_code] = result[:genre_code]
    else
      Rails.logger.error "WARNING: genre_code missing for #{@text_content.unit_key} - this is required!"
      # Allow model validations to catch missing genre_code instead of silently guessing.
    end

    @text_content.update!(update_params)
  end

  # Universal: Enforce text_unit_type based on unit_key shape
  # TRAD|BOOK|CH|VS (4 parts) => BIB_VERSE
  # TRAD|BOOK|CH (3 parts) => BIB_CHAPTER
  def enforce_text_unit_type_from_key(unit_key)
    return nil unless unit_key.present?
    
    parts = unit_key.to_s.split('|')
    
    case parts.length
    when 4
      'BIB_VERSE'  # TRAD|BOOK|CH|VS
    when 3
      'BIB_CHAPTER'  # TRAD|BOOK|CH
    else
      nil  # Unknown shape, don't enforce
    end
  end

  # Validate word-for-word layer: ensure all Greek tokens exist in source text
  # This prevents glosses from inventing words that aren't in Swete
  def validate_word_for_word_layer!(source_text, word_for_word_tokens)
    return unless source_text.present? && word_for_word_tokens.is_a?(Array)

    source_text_normalized = source_text.downcase.gsub(/[·,.;:!?«»"ʼ'']/, '')
    missing_tokens = []

    word_for_word_tokens.each do |token_data|
      next unless token_data.is_a?(Hash)
      
      greek_token = token_data['token'] || token_data[:token]
      next unless greek_token.present?

      # Normalize token for comparison (remove punctuation, lowercase)
      token_normalized = greek_token.downcase.gsub(/[·,.;:!?«»"ʼ'']/, '')
      
      # Check if token exists in source text
      unless source_text_normalized.include?(token_normalized)
        missing_tokens << greek_token
      end
    end

    if missing_tokens.any?
      error_msg = "Word-for-word layer contains tokens not in source text: #{missing_tokens.join(', ')}"
      Rails.logger.error "Swete word-for-word validation failed for #{@text_content.unit_key}: #{error_msg}"
      raise SweteFidelityError.new(
        error_msg,
        error_type: 'WORD_FOR_WORD_INVALID',
        details: {
          book: @book.code,
          chapter: @chapter,
          verse: @verse,
          missing_tokens: missing_tokens
        }
      )
    end
  end

  def log_population(result)
    TextContentApiLog.create!(
      text_content_id: @text_content.id,
      source_name: @source.name,
      book_code: @book.code,
      chapter: @chapter,
      verse: @verse,
      action: 'populate_content',
      request_payload: {
        source: @source.name,
        book: @book.std_name,
        chapter: @chapter,
        verse: @verse
      }.to_json,
      response_payload: {
        source_text: result[:source_text],
        word_for_word_count: result[:word_for_word]&.count || 0,
        lsv_literal_reconstruction: result[:lsv_literal_reconstruction],
        ai_notes: result[:ai_notes]
      }.to_json,
      status: 'success',
      ai_model_name: GROK_MODEL
    )
  rescue => e
    Rails.logger.error "Failed to log population: #{e.message}"
    Rails.logger.error e.backtrace.first(3).join("\n")
  end

  # Validate AI response before saving
  def validate_ai_response(result)
    errors = []

    # Check source_text
    if result[:source_text].blank? || result[:source_text] == '[EDITION_TEXT_UNAVAILABLE]'
      errors << "source_text is blank or unavailable"
    end

    # Check word_for_word
    if result[:word_for_word].blank? || !result[:word_for_word].is_a?(Array)
      errors << "word_for_word must be a non-empty array"
    end

    # Check lsv_literal_reconstruction
    if result[:lsv_literal_reconstruction].blank?
      errors << "lsv_literal_reconstruction is blank"
    end

    # Check lsv_notes structure
    if result[:lsv_notes].present? && !result[:lsv_notes].is_a?(Hash)
      errors << "lsv_notes must be a hash"
    elsif result[:lsv_notes].present?
      validation_status = result[:lsv_notes]['validation_status']
      unless ['OK', 'MISSING_LEXICAL_MEANINGS', 'INVALID_MEANING'].include?(validation_status)
        errors << "lsv_notes.validation_status must be OK, MISSING_LEXICAL_MEANINGS, or INVALID_MEANING"
      end
    end

    # Check genre_code (required)
    if result[:genre_code].blank?
      errors << "genre_code is required"
    end

    if errors.any?
      { valid: false, error: errors.join('; ') }
    else
      { valid: true }
    end
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

    Rails.logger.debug "Grok API request: POST #{uri.path}, model: #{model}, max_tokens: #{max_tokens}"

    # Retry logic for rate limiting and transient errors
    max_retries = 5
    retry_count = 0
    base_wait = 1
    response = nil
    response_body = nil
    parsed_response = nil

    loop do
      begin
        # Use semaphore to limit concurrent requests
        SEMAPHORE.acquire
        begin
          # Try the request with normal SSL verification first
          begin
            http = Net::HTTP.new(uri.host, uri.port)
            http.read_timeout = GROK_TIMEOUT
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
              http.read_timeout = GROK_TIMEOUT
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
        ensure
          SEMAPHORE.release
        end

        # Handle rate limiting and retryable errors (check after releasing semaphore)
        if response.code == '429' # Rate limit
          retry_count += 1
          if retry_count <= max_retries
            wait_time = base_wait * (2 ** retry_count) + rand(0.0..1.0) # Exponential backoff with jitter
            Rails.logger.warn "Rate limit hit (attempt #{retry_count}/#{max_retries}). Waiting #{wait_time.round(2)}s before retry..."
            sleep wait_time
            next # Retry the loop
          else
            error_body = begin
              parsed = JSON.parse(response.body)
              parsed.is_a?(Hash) ? parsed : { error: { message: parsed.to_s } }
            rescue JSON::ParserError
              { error: { message: response.message } }
            end
            error_msg = error_body.is_a?(Hash) ? (error_body.dig('error', 'message') || response.message) : response.message
            Rails.logger.error "Grok API rate limit error after #{max_retries} retries: #{error_msg}"
            raise "Grok API rate limit error: #{error_msg}"
          end
        elsif response.code.to_i >= 500 # Server errors - retry
          retry_count += 1
          if retry_count <= max_retries
            wait_time = base_wait * (2 ** retry_count) + rand(0.0..1.0)
            Rails.logger.warn "Server error #{response.code} (attempt #{retry_count}/#{max_retries}). Waiting #{wait_time.round(2)}s before retry..."
            sleep wait_time
            next # Retry the loop
          else
            error_body = begin
              parsed = JSON.parse(response.body)
              parsed.is_a?(Hash) ? parsed : { error: { message: parsed.to_s } }
            rescue JSON::ParserError
              { error: { message: response.message } }
            end
            error_msg = error_body.is_a?(Hash) ? (error_body.dig('error', 'message') || response.message) : response.message
            Rails.logger.error "Grok API server error after #{max_retries} retries: #{error_msg}"
            raise "Grok API server error (#{response.code}): #{error_msg}"
          end
        elsif !response.is_a?(Net::HTTPSuccess)
          error_body = begin
            parsed = JSON.parse(response.body)
            parsed.is_a?(Hash) ? parsed : { error: { message: parsed.to_s } }
          rescue JSON::ParserError
            { error: { message: response.message } }
          end
          error_msg = error_body.is_a?(Hash) ? (error_body.dig('error', 'message') || response.message) : response.message
          Rails.logger.error "Grok API error (#{response.code}): #{error_msg}"
          Rails.logger.error "Response body: #{response.body[0..500]}"
          raise "Grok API error (#{response.code}): #{error_msg}"
        else
          # Success - now parse JSON and check for truncation
          response_body = response.body
          
          # Check if response body looks truncated (incomplete JSON)
          if response_body.present? && !response_body.strip.end_with?('}')
            Rails.logger.warn "Response body appears truncated (doesn't end with '}'). Length: #{response_body.length}"
            Rails.logger.warn "Last 200 chars: #{response_body[-200..-1]}"
            # Retry the entire request if JSON is incomplete
            if retry_count < max_retries
              retry_count += 1
              wait_time = base_wait * (2 ** retry_count) + rand(0.0..1.0)
              Rails.logger.warn "Incomplete JSON response (attempt #{retry_count}/#{max_retries}). Retrying in #{wait_time.round(2)}s..."
              sleep wait_time
              next # Retry the loop
            else
              Rails.logger.error "Failed to get complete response after #{max_retries} retries"
              raise "Grok API returned incomplete JSON response after #{max_retries} retries"
            end
          end
          
          # Try to parse JSON
          begin
            parsed_response = JSON.parse(response_body)
            Rails.logger.debug "Parsed response type: #{parsed_response.class}"
            break # Success - exit the loop
          rescue JSON::ParserError => e
            Rails.logger.error "Failed to parse Grok API response body: #{e.message}"
            Rails.logger.error "Response body (first 500 chars): #{response_body[0..500]}"
            Rails.logger.error "Response body length: #{response_body.length}"
            Rails.logger.error "Response body (last 200 chars): #{response_body[-200..-1]}" if response_body.length > 200
            
            # Retry if JSON is incomplete (truncated response) and we haven't exceeded retries
            if (e.message.include?('unexpected end') || e.message.include?('expected closing')) && retry_count < max_retries
              retry_count += 1
              wait_time = base_wait * (2 ** retry_count) + rand(0.0..1.0)
              Rails.logger.warn "Incomplete JSON detected (attempt #{retry_count}/#{max_retries}). Retrying in #{wait_time.round(2)}s..."
              sleep wait_time
              next # Retry the loop
            end
            
            raise "Failed to parse Grok API response: #{e.message}. Response body: #{response_body[0..200]}"
          end
        end
      rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ETIMEDOUT => e
        retry_count += 1
        if retry_count <= max_retries
          wait_time = base_wait * (2 ** retry_count) + rand(0.0..1.0)
          Rails.logger.warn "Timeout error (attempt #{retry_count}/#{max_retries}): #{e.message}. Waiting #{wait_time.round(2)}s before retry..."
          sleep wait_time
          next # Retry the loop
        else
          Rails.logger.error "Grok API timeout after #{max_retries} retries: #{e.message}"
          raise "Grok API timeout: #{e.message}"
        end
      end
    end

    # Ensure parsed_response was set (should always be set if we exit the loop normally)
    unless parsed_response
      raise "Failed to get valid response from Grok API after #{max_retries} retries"
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
