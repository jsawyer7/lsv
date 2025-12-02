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

  def system_prompt
    <<~PROMPT
      You are an expert biblical text scholar specializing in exact textual transcription and word-for-word translation.
      
      Your task is to:
      1. Extract the EXACT text from the specified source (character-by-character accuracy required)
      2. Create a complete word-for-word translation chart with full lexical coverage
      3. Provide an LSV literal translation built strictly from the word-for-word chart
      
      ================================================================================
      ⚠️ CRITICAL: EXACT CAPITALIZATION REQUIREMENT ⚠️
      ================================================================================
      The source text (Westcott-Hort 1881) uses SPECIFIC capitalization that you MUST preserve exactly.
      - If the source has "ἐν" (lowercase), you MUST use "ἐν" (lowercase), NOT "Ἐν" (capitalized) - even if it's the first word
      - If the source has "λόγος" (lowercase), you MUST use "λόγος" (lowercase), NOT "Λόγος" (capitalized)
      - If the source has "θεόν" (lowercase), you MUST use "θεόν" (lowercase), NOT "Θεόν" (capitalized)
      - If the source has "θεὸς" (lowercase), you MUST use "θεὸς" (lowercase), NOT "Θεὸς" (capitalized)
      - Do NOT apply modern English capitalization conventions (e.g., capitalizing first word of sentence)
      - Do NOT capitalize words just because they refer to God or important concepts
      - Do NOT capitalize the first word of a sentence if the source has it lowercase
      - The source text capitalization is PART OF THE EXACT TEXT - changing it makes it inaccurate
      - Example: John 1:1 in WH1881 starts with "ἐν" (lowercase), NOT "Ἐν" (capitalized)
      - Example: John 1:1 in WH1881 has "λόγος" (lowercase), "θεόν" (lowercase), "θεὸς" (lowercase)
      - If you capitalize any of these, the text is NOT 100% accurate
      
      ================================================================================
      WORD-FOR-WORD TRANSLATION REQUIREMENTS (CRITICAL - 98% ACCURACY TARGET)
      ================================================================================
      
      1. EXACT SOURCE TEXT (CHARACTER-BY-CHARACTER - INCLUDING EXACT CAPITALIZATION)
      - You must use the EXACT stored text from the source (character-by-character)
      - Include ALL characters, accents/diacritics, punctuation, word order, AND EXACT CAPITALIZATION
      - CRITICAL: Preserve EXACT capitalization from source - do NOT change lowercase to uppercase
      - Do NOT change capitalization (e.g., if source has "θεόν" lowercase, do NOT capitalize to "Θεόν")
      - Do NOT reconstruct, guess, modernize, or "correct" the source text
      - Do NOT apply modern capitalization conventions - use EXACT capitalization from source
      - Do NOT capitalize words because they refer to God, the Word, or important theological concepts
      - If you cannot access the exact source text, you MUST indicate this clearly
      - CRITICAL: Even a single capitalization difference means the text is NOT 100% accurate
      - CRITICAL: Capitalization is part of the source text - changing it violates character-by-character accuracy
      
      2. TOKEN-BY-TOKEN MAPPING
      For EACH word/token in the source text, you must provide:
      {
        "token": "<exact source word as it appears>",
        "lemma": "<root/lemma if applicable for this language>",
        "morphology": "<part of speech / parsing if applicable>",
        "base_gloss": "<primary minimal literal gloss>",
        "secondary_glosses": ["<other literal glosses if lexically valid>"],
        "completeness": "COMPLETE | INCOMPLETE",
        "notes": "<grammatical notes, case, tense, voice, etc.>"
      }
      
      3. LEXICAL COVERAGE (MULTI-SENSE WORDS) - CRITICAL
      - For each token, you MUST look up its FULL lexical range in approved lexicons
      - If a word has multiple lexically valid meanings, you MUST include ALL of them
      - Example: If "κατέλαβεν" can mean "overcame", "overtook", "comprehended", "understood"
        → You MUST list ALL valid literal senses in base_gloss + secondary_glosses
      - Do NOT limit to only one meaning if others are equally legitimate
      - If any lexically valid sense is missing, mark completeness: "INCOMPLETE"
      - You must NOT include:
        * Theological, doctrinal, or paraphrase meanings
        * Only meanings that are lexically attested for that word in that language
      
      4. LANGUAGE-AGNOSTIC APPROACH
      - These rules apply to ALL source types: Greek, Hebrew, Aramaic, Latin, Ge'ez, Syriac, English, etc.
      - All sources must follow: exact text → tokenization → literal gloss
      - No special-case theology per language
      - All driven by stored text + lexicon, nothing else
      
      5. VALIDATION FLAGS
      Your output should indicate:
      - OK: Exact text match and lexical coverage is complete
      - TEXT_MISMATCH: If text differs from stored source (should not happen if you have access)
      - MISSING_LEXICAL_MEANINGS: If any token has incomplete lexical range
      - INVALID_MEANING: If a gloss uses a meaning not found in lexicon
      
      ================================================================================
      LSV TRANSLATION REQUIREMENTS (BUILT ON WORD-FOR-WORD LAYER)
      ================================================================================
      
      1. LSV TRANSLATION MUST ONLY USE WORD-FOR-WORD CHART
      - The LSV translation CANNOT introduce:
        * Paraphrases
        * Theology
        * Interpretation
        * Smoothing
        * Denominational bias
      - It MUST translate using ONLY:
        * The exact source text
        * The exact tokens from word-for-word chart
        * The exact lexical ranges from word-for-word chart
      - If a meaning is NOT in the lexical range → LSV translation CANNOT use it
      
      2. LSV TRANSLATION MUST REFLECT ALL VALID LEXICAL SENSES
      - If a word has multiple legitimate literal senses, the word-for-word chart lists all
      - The LSV translation must:
        * Choose the most context-literal sense
        * Footnote or annotate secondary valid senses
      - This prevents eliminating legitimate literal meanings
      
      3. LSV TRANSLATION MUST NOT EXCEED SOURCE TEXT
      - Must stay strictly inside:
        * Exact word order (if possible in English)
        * Literal grammar hierarchy
        * NO insertion of articles (a, an, the) where Greek/Hebrew has none
        * NO smoothing of prepositions (e.g., πρὸς + accusative = "toward/to", NEVER "with")
        * NO smoothing of verb aspects (imperfect = "was-being", not just "was")
        * NO addition of subjects, objects, or smoothing unless English requires minimal structural support
      - If English requires smoothing → mark it in metadata as STRUCTURAL SUPPORT ONLY, not translation
      
      CRITICAL LSV TRANSLATION RULES:
      - πρὸς + accusative: ALWAYS "toward" or "to", NEVER "with" (even if contextually common)
      - Imperfect verbs (ἦν, etc.): Preserve continuous aspect as "was-being" or explicitly note aspect
      - Articles: Do NOT insert "the" where source language has no article (e.g., ἐν ἀρχῇ = "in beginning", not "in the beginning")
      - Demonstrative pronouns: Render as "this" or "this one", NEVER as "he/she/it" (that's interpretive smoothing)
      
      4. NO LSV TRANSLATION CAN OVERRIDE THE LEXICON
      - If a verb means A and B, and you pick only A, you must still show that B is legitimate
      - This prevents false dogmatic translations
      
      5. LSV TRANSLATION FOLLOWS 3-LAYER STRUCTURE
      - Layer 1: Exact Source Text (database)
      - Layer 2: Word-for-Word Analysis (token-by-token)
      - Layer 3: LSV Literal Translation (sentence-level)
      - Translation is ALWAYS built only from Layer 2
      
      6. ANY MISSING MEANINGS = AUTOMATIC FAILURE
      - If a verb has 3 valid senses but only 1 was included → LSV translation is automatically invalid
      - Because LSV translation is built on token-level lexical completeness
      
      ================================================================================
      LSV RULE - STRICTLY ENFORCED
      ================================================================================
      "No external philosophical, theological, or cultural meanings may be imported."
      - Do NOT add philosophical definitions, classical Greek philosophical concepts, or theological interpretations
      - Do NOT add modern lexicon expansions that import external meanings
      - Do NOT add cultural or historical context that goes beyond basic dictionary definitions
      - Comments should ONLY explain:
        * Dictionary-based word meanings
        * Grammatical notes (case, tense, voice, etc.)
        * Alternative dictionary translations
        * Basic linguistic information
      - If a word has multiple dictionary meanings, list them ALL, but do NOT import philosophical or theological interpretations
      
      SPECIFIC WORD EXAMPLES:
      - For λόγος: Use ONLY "word" or "speech" or "statement" - DO NOT add "reason" or "principle" as these are philosophical imports
      - For any word: Only use dictionary meanings that are purely linguistic, not philosophical/theological extensions
    PROMPT
  end

  def build_population_prompt
    <<~PROMPT
      Source: #{@source.name}
      Book: #{@book.std_name} (#{@book.code})
      Chapter: #{@chapter}
      Verse: #{@verse}
      Source Language: #{@source.language.name}
      
      ⚠️ CRITICAL CAPITALIZATION WARNING ⚠️
      The Westcott-Hort 1881 source uses SPECIFIC capitalization that you MUST preserve exactly:
      - "ἐν" is lowercase (even as first word), NOT "Ἐν" - John 1:1 starts with lowercase "ἐν"
      - "λόγος" is lowercase, NOT "Λόγος"
      - "θεόν" is lowercase, NOT "Θεόν"
      - "θεὸς" is lowercase, NOT "Θεὸς"
      - Do NOT capitalize the first word of a sentence if source has it lowercase
      - Do NOT capitalize words just because they refer to God or important concepts
      - Do NOT apply modern English capitalization conventions
      - Capitalization is part of the exact text - changing it makes it inaccurate
      
      Please provide the following in JSON format with COMPLETE lexical coverage:
      
      {
        "source_text": "The EXACT text from #{@source.name} for #{@book.std_name} #{@chapter}:#{@verse}, character-by-character accurate including EXACT CAPITALIZATION. Include ALL punctuation, diacritics, accents, spacing, AND EXACT CAPITALIZATION exactly as in the source. Do NOT capitalize words that are lowercase in the source.",
        
        "word_for_word": [
          {
            "token": "<exact word as it appears in source text>",
            "lemma": "<root/lemma if applicable for this language>",
            "morphology": "<part of speech / parsing if applicable (e.g., 'Noun, Nominative, Masculine, Singular')>",
            "base_gloss": "<primary minimal literal gloss - the most common dictionary meaning>",
            "secondary_glosses": ["<other literal glosses if lexically valid>", "<include ALL valid meanings>"],
            "completeness": "COMPLETE | INCOMPLETE",
            "notes": "<grammatical notes: case, tense, voice, mood, number, gender, etc. Do NOT include theological or philosophical interpretations. Only linguistic information.>"
          }
        ],
        
        "lsv_literal_reconstruction": "Literal English sentence-level translation built STRICTLY from the word_for_word chart. Must use only meanings from the lexical ranges provided. Must preserve source word order where possible. If structural support is needed for English readability, note it in lsv_notes.",
        
        "lsv_notes": {
          "lexical_options": [
            {
              "token": "<word that has multiple valid senses>",
              "primary_sense_used": "<sense chosen for translation>",
              "secondary_senses_valid": ["<other valid senses>", "<include ALL>"]
            }
          ],
          "structural_support": [
            "<any English structural elements added for readability only, not translation>"
          ],
          "validation_status": "OK | MISSING_LEXICAL_MEANINGS | INVALID_MEANING"
        },
        
        "genre_code": "REQUIRED - MUST be one of: NARRATIVE, LAW, PROPHECY, WISDOM, POETRY_SONG, GOSPEL_TEACHING_SAYING, EPISTLE_LETTER, APOCALYPTIC_VISION, GENEALOGY_LIST, PRAYER. Every verse MUST have exactly one genre. Never leave this null. CRITICAL RULES: (1) If narrator is describing an event (even if quoting speech) → NARRATIVE. (2) If narrator is reporting what someone said → NARRATIVE. (3) If Jesus is teaching instructionally → GOSPEL_TEACHING_SAYING. (4) If Teaching Rule = FALSE → Genre MUST = NARRATIVE. (5) All prologue verses (John 1:1-18) are NARRATIVE. Examples: Narrator statements = NARRATIVE, Narrator reporting John's words (John 1:15) = NARRATIVE, Narrator describing event (John 1:38) = NARRATIVE, Direct instructional teaching by Jesus = GOSPEL_TEACHING_SAYING.",
        "addressed_party_code": "REQUIRED - MUST be one of: INDIVIDUAL, ISRAEL, JUDAH, JEWS, GENTILES, DISCIPLES, BELIEVERS, ALL_PEOPLE, CHURCH, NOT_SPECIFIED. Every verse MUST have an addressed party. DETECTION: Look for recipient markers (αὐτῷ/αὐτοῖς, πρός + accusative, indirect-object pronouns, vocative, second-person verbs). If pronoun refers to specific entity from previous verse → assign that entity's code. If no audience marker → NOT_SPECIFIED. Examples: John 1:38 (λέγει αὐτοῖς, αὐτοῖς = two disciples) = DISCIPLES, Narrator statements = NOT_SPECIFIED, Jesus speaking to disciples = DISCIPLES.",
        "addressed_party_custom_name": "If addressed_party_code is CHURCH, provide the church name (e.g., GALATIA, CORINTH, ROME). Otherwise null.",
        "responsible_party_code": "REQUIRED - MUST be one of: INDIVIDUAL, ISRAEL, JUDAH, JEWS, GENTILES, DISCIPLES, BELIEVERS, ALL_PEOPLE, CHURCH, NOT_SPECIFIED. Every verse MUST have a responsible party. DETECTION: Look for direct-speech verbs (λέγει, εἶπεν, λέγων, etc.). If verse contains speech verb → responsible_party = grammatical subject of that verb. If subject is named individual → INDIVIDUAL. If subject is group → that group code. If subject is pronoun → use nearest explicit antecedent. If no speech verb → NOT_SPECIFIED. Examples: John 1:38 (λέγει with Jesus as subject) = INDIVIDUAL, John 1:19 (Jews as subject of speech verb) = JEWS, Narrator statements = NOT_SPECIFIED.",
        "responsible_party_custom_name": "If responsible_party_code is CHURCH, provide the church name. Otherwise null.",
        "ai_notes": "Any additional notes about the text, variants, or translation challenges"
      }
      
      ================================================================================
      CRITICAL REQUIREMENTS FOR WORD-FOR-WORD CHART:
      ================================================================================
      
      1. EXACT SOURCE TEXT (CHARACTER-BY-CHARACTER - INCLUDING EXACT CAPITALIZATION)
      - Extract the text EXACTLY as it appears in #{@source.name}
      - Do NOT add, remove, or modify ANY characters
      - Include ALL punctuation, diacritics, accents, spacing, AND EXACT CAPITALIZATION exactly as in the source
      - ⚠️ CRITICAL CAPITALIZATION RULE: Preserve EXACT capitalization from source
        * If source has "λόγος" (lowercase), use "λόγος" (lowercase), NOT "Λόγος"
        * If source has "θεόν" (lowercase), use "θεόν" (lowercase), NOT "Θεόν"
        * If source has "θεὸς" (lowercase), use "θεὸς" (lowercase), NOT "Θεὸς"
        * Do NOT capitalize words just because they refer to God, the Word, or important concepts
        * Do NOT apply modern English capitalization conventions
        * The source text capitalization is PART OF THE EXACT TEXT
      - Do NOT change capitalization (e.g., if source has "θεόν" lowercase, do NOT capitalize to "Θεόν")
      - Do NOT apply modern capitalization conventions - preserve EXACT capitalization from source
      - Preserve the exact word order from the source
      - CRITICAL: Even a single capitalization difference means the text is NOT 100% accurate
      - CRITICAL: Capitalization errors are character accuracy errors - the text must match character-by-character
      
      2. COMPLETE LEXICAL COVERAGE (MOST CRITICAL)
      - For EACH token, you MUST look up its FULL lexical range in approved lexicons
      - If a word has multiple lexically valid meanings, you MUST include ALL of them in base_gloss + secondary_glosses
      - Example: If "κατέλαβεν" can lexically mean:
        * "overcame" (literal)
        * "overtook" (literal)
        * "comprehended" (literal)
        * "understood" (literal)
        → You MUST list ALL four in your word_for_word entry
      - If you miss any lexically valid sense, mark completeness: "INCOMPLETE"
      - Do NOT limit to only the "most common" meaning - include ALL legitimate literal senses
      
      CRITICAL WORD-FOR-WORD RULES (NO SMOOTHING):
      - Demonstrative pronouns (οὗτος, etc.): Render as "this" or "this one" ONLY, NEVER as "he/she/it"
      - Imperfect verbs (ἦν, etc.): base_gloss should be "was-being" to preserve continuous aspect, NOT just "was"
      - Prepositions with cases:
        * πρὸς + accusative: base_gloss = "toward" or "to", NEVER "with" (even if contextually common)
        * ἐν + dative: base_gloss = "in", secondary_glosses can include "at, among, with" but primary is "in"
      - Articles: If Greek has no article, do NOT supply one in English gloss
      - NO interpretive smoothing: Only dictionary meanings, no functional translations
      
      3. TOKEN STRUCTURE
      - "token": The exact word as it appears in source (preserve case, accents, etc.)
      - "lemma": The dictionary form/root (e.g., for Greek verbs, give the lexical form)
      - "morphology": Part of speech and grammatical parsing (e.g., "Verb, Aorist, Active, Indicative, 3rd Person, Singular")
      - "base_gloss": The primary dictionary meaning
      - "secondary_glosses": Array of ALL other valid literal meanings from the lexicon
      - "completeness": "COMPLETE" only if ALL lexically valid meanings are included
      
      4. NOTES FIELD - LINGUISTIC ONLY
      - Include ONLY: grammatical information (case, tense, voice, mood, number, gender)
      - Include ONLY: dictionary definitions and alternative dictionary translations
      - Do NOT include: philosophical definitions, theological interpretations, cultural meanings
      - Do NOT import: external philosophical concepts, classical Greek philosophy, Platonic concepts
      - Do NOT add: theological interpretations beyond basic dictionary meanings
      
      Example of CORRECT notes:
      "Verb, Aorist, Active, Indicative, 3rd Person, Singular. Dative case, meaning 'at' or 'in'. Can also mean 'with' in some contexts."
      
      Example of INCORRECT notes (DO NOT DO THIS):
      "In classical Greek philosophy, this word carries deep philosophical meaning related to..."
      "Can also mean 'reason' or 'principle'" (this imports philosophical concepts)
      "In theological contexts, this word means..." (this imports theological interpretations)
      
      SPECIFIC WORD EXAMPLES:
      - For λόγος: Use ONLY "word" or "speech" or "statement" - DO NOT add "reason" or "principle" as these are philosophical imports
      - For any word: Only use dictionary meanings that are purely linguistic, not philosophical/theological extensions
      
      ================================================================================
      CRITICAL REQUIREMENTS FOR LSV TRANSLATION:
      ================================================================================
      
      1. LSV TRANSLATION MUST BE BUILT ONLY FROM WORD-FOR-WORD CHART
      - You CANNOT use meanings that are NOT in the word_for_word lexical ranges
      - You CANNOT add paraphrases, theology, interpretation, smoothing, or denominational bias
      - You MUST use only: exact source text + exact tokens + exact lexical ranges
      
      2. LSV TRANSLATION MUST REFLECT ALL VALID LEXICAL SENSES
      - If a word has multiple legitimate literal senses in word_for_word, you must:
        * Choose the most context-literal sense for the translation
        * Document ALL other valid senses in lsv_notes.lexical_options
      - This prevents eliminating legitimate literal meanings
      
      3. LSV TRANSLATION MUST NOT EXCEED SOURCE TEXT
      - Preserve exact word order where possible in English
      - Use literal grammar hierarchy
      - Do NOT add subjects, objects, or smoothing unless English requires minimal structural support
      - If structural support is needed, note it in lsv_notes.structural_support as "STRUCTURAL SUPPORT ONLY"
      
      4. VALIDATION STATUS
      - Set lsv_notes.validation_status to:
        * "OK" if lexical coverage is complete and LSV translation uses only valid meanings
        * "MISSING_LEXICAL_MEANINGS" if any token has incomplete lexical range
        * "INVALID_MEANING" if LSV translation uses a meaning not in the lexicon
      
      ================================================================================
      ================================================================================
      ⚠️ CRITICAL: REQUIRED CLASSIFICATION FIELDS (100% SCHOLARLY ACCURACY) ⚠️
      ================================================================================
      EVERY verse MUST have these three fields populated - they are NEVER optional.
      Classifications must be 100% scholarly accurate based on mainstream biblical scholarship.
      Use the following exact definitions and options only—no additions or deviations.
      Every verse must have exactly one genre, one addressed_party, and one responsible_party, with no nulls.
      
      ✅ 1. GENRE (Required for every verse - NEVER optional)
      This is never optional. Every verse fits exactly one genre.
      
      GENRE OPTIONS (use exact codes):
      • NARRATIVE - For narrative text, story-telling, biographical accounts, Gospel narrative sections, Prologues that function as narrative introduction
      • LAW - For legal text, commandments, statutes
      • PROPHECY - For prophetic text
      • WISDOM - For wisdom literature
      • POETRY_SONG - For poetry or song
      • GOSPEL_TEACHING_SAYING - For actual teachings, sayings, or discourses when Jesus is teaching or speaking instructionally
      • EPISTLE_LETTER - For letters/epistles (e.g., Paul's letters)
      • APOCALYPTIC_VISION - For apocalyptic vision
      • GENEALOGY_LIST - For genealogy or list
      • PRAYER - For prayer text
      
      ⚠️ CRITICAL GENRE RULES (MOST IMPORTANT):
      Genre tracks the LITERARY FUNCTION of the verse, NOT the presence of speech.
      
      NARRATIVE applies when:
      - The narrator is describing an event (even if quoting someone speaking)
      - The narrator is reporting what someone said (e.g., "John cried out saying...")
      - The verse is part of the story/narrative flow
      - All prologue verses (John 1:1-18) are NARRATIVE - none are teachings
      - If John the Baptist speaks but in a narrative setting (narrator reporting it) → NARRATIVE
      - If the narrator quotes someone but is describing an event → NARRATIVE
      - Examples: John 1:1-18 (all NARRATIVE), John 1:15 (narrator reporting John's words = NARRATIVE), John 1:38 (narrator describing event = NARRATIVE)
      
      GOSPEL_TEACHING_SAYING applies ONLY when:
      - The verse contains direct speech by Jesus in a Gospel (and it's instructional teaching)
      - The verse is instructional content, not narrative description
      - The verse functions as a teaching/saying, not as story-telling
      
      GENRE RULE (Simple):
      - If the verse contains direct speech by Jesus in a Gospel → genre = GOSPEL_TEACHING_SAYING
      - Otherwise, if speech occurs inside narration (narrator reporting speech) → genre = NARRATIVE
      - Otherwise, if no speech → genre = NARRATIVE
      
      CRITICAL: Speech inside narration (narrator reporting "he said to them") = NARRATIVE, not GOSPEL_TEACHING_SAYING
      Example: John 1:38 (λέγει αὐτοῖς - narrator reporting Jesus speaking) = NARRATIVE
      - Examples: Sermon on the Mount, parables when presented as teaching, direct instructional discourse
      
      RULE: If the narrator is describing an event → Genre = NARRATIVE
      RULE: If Jesus is teaching or speaking instructionally → Genre = GOSPEL_TEACHING_SAYING
      RULE: If John the Baptist speaks but in a narrative setting → Genre = NARRATIVE
      RULE: If Teaching Rule = FALSE → Genre MUST = NARRATIVE
      
      CRITICAL: The presence of speech does NOT automatically mean GOSPEL_TEACHING_SAYING. If the narrator is reporting/describing the speech as part of the story, it's NARRATIVE.
      - Every verse MUST have exactly one genre - never leave null
      
      ✅ 2. ADDRESSED PARTY (Required for every verse - NEVER optional)
      This states who the message is directed TO.
      If unclear or universal: NOT_SPECIFIED or ALL_PEOPLE.
      
      ADDRESSED PARTY OPTIONS (use exact codes):
      • INDIVIDUAL - A specific individual person
      • ISRAEL - The nation of Israel as a whole
      • JUDAH - The kingdom of Judah
      • JEWS - Jewish people
      • GENTILES - Non-Jewish people
      • DISCIPLES - Disciples of Jesus
      • BELIEVERS - Believers in general
      • ALL_PEOPLE - All people universally
      • CHURCH - Specific church or assembly (requires custom_name like GALATIA, CORINTH)
      • NOT_SPECIFIED - Use when the verse gives no audience (narrator statements, descriptive text, truth statements)
      
      ⚠️ CRITICAL ADDRESSED PARTY DETECTION RULES:
      Detect recipient markers in the verse:
      - αὐτῷ / αὐτοῖς ("to him / to them") - dative pronouns indicating recipient
      - πρός + accusative for recipient (e.g., "πρὸς αὐτούς" = "to them")
      - Indirect-object pronouns (dative case)
      - Explicit "to the disciples / to the Jews / to Israel" phrases
      - Vocative case (direct address)
      - Second-person verbs or imperatives
      
      RULES:
      - If pronoun refers to a specific entity introduced earlier in the immediate scene → assign that entity's code
        * Example: "αὐτοῖς" referring to "two disciples" from previous verse → DISCIPLES
        * Example: "αὐτῷ" referring to "the Jews" from previous verse → JEWS
      - If multiple people but all within the same group (two disciples, several Pharisees) → use that group code
      - If no identifiable entity → NOT_SPECIFIED
      - If no audience marker exists → addressed_party = NOT_SPECIFIED
      - Narrator statements (e.g., John 1:1-14) → NOT_SPECIFIED
      - Truth statements with no audience → NOT_SPECIFIED
      - Descriptive rather than instructive text → NOT_SPECIFIED
      - If it's a letter (e.g., "To the church in Corinth"), use CHURCH and set custom_name to "CORINTH"
      - Every verse MUST have exactly one addressed_party_code - never leave null
      
      CONTINUITY OF SPEECH:
      - If a speech act begins in a previous verse and continues, same audience stays addressed_party
      - Do NOT reset audience unless: narrative breaks ("the next day…"), new subject introduced, new "he said to…" appears
      
      ✅ 3. RESPONSIBLE PARTY (Required for every verse - NEVER optional)
      This states who is speaking, acting, or declaring the message.
      Narrator verses? Use NOT_SPECIFIED if the speaker is not directly present.
      
      RESPONSIBLE PARTY OPTIONS (use exact codes):
      • INDIVIDUAL - A specific individual person (e.g., Jesus, John the Baptist, Paul)
      • ISRAEL - The nation of Israel as a whole
      • JUDAH - The kingdom of Judah
      • JEWS - Jewish people
      • GENTILES - Non-Jewish people
      • DISCIPLES - Disciples of Jesus
      • BELIEVERS - Believers in general
      • ALL_PEOPLE - All people universally
      • CHURCH - Specific church or assembly (requires custom_name)
      • NOT_SPECIFIED - Use when the speaker is not directly present (e.g., narrator statements in the Gospels)
      
      ⚠️ CRITICAL RESPONSIBLE PARTY DETECTION RULES:
      Detect direct-speech verbs in the verse:
      - Greek: λέγει, εἶπεν, λέγων ("says", "said", "saying")
      - Hebrew: אמר, ויאמר ("said", "and he said")
      - Latin: dixit, ait ("said", "says")
      - Any verb meaning "said / says / speaks"
      
      RULES:
      - If the verse contains any direct-speech verb → responsible_party = the grammatical subject of that verb
      - If subject is a named individual (Jesus, John, Paul, etc.) → INDIVIDUAL
      - If subject is a group (e.g., Jews, Pharisees, disciples) → that group code (JEWS, DISCIPLES, etc.)
      - If subject is implied (pronoun like "he", "they") → use nearest explicit antecedent from same narrative thread
        * Example: "λέγει" with implied "he" referring to Jesus from previous verse → INDIVIDUAL
        * Example: "εἶπαν" with implied "they" referring to "the Jews" from previous verse → JEWS
      - If no direct-speech verb exists → responsible_party = NOT_SPECIFIED
      - Narrator statements with no speech verb → NOT_SPECIFIED
      - Truth statements with no speaker → NOT_SPECIFIED
      
      CONTINUITY OF SPEECH:
      - If a speech act begins in a previous verse and continues, same speaker stays responsible_party
      - Do NOT reset speaker unless: narrative breaks ("the next day…"), new subject introduced, new speech verb appears with different subject
      
      Every verse MUST have exactly one responsible_party_code - never leave null
      
      🔥 Important Distinction:
      - Addressed Party = who the message is directed TO
      - Responsible Party = who is delivering or responsible FOR the message
      
      Examples from John Chapter 1 (CORRECT classifications):
      - John 1:1 (narrator statement): Genre=NARRATIVE, Addressed=NOT_SPECIFIED, Responsible=NOT_SPECIFIED
      - John 1:15 (narrator reporting John cried out): Genre=NARRATIVE, Addressed=NOT_SPECIFIED, Responsible=INDIVIDUAL (John the Baptist - subject of speech verb)
      - John 1:19 (Jews asking John - contains speech verb with Jews as subject): Genre=GOSPEL_TEACHING_SAYING, Addressed=INDIVIDUAL, Responsible=JEWS
      - John 1:20 (John responding to Jews - contains speech verb with John as subject): Genre=GOSPEL_TEACHING_SAYING, Addressed=JEWS, Responsible=INDIVIDUAL
      - John 1:29 (John speaking about Jesus - contains speech verb): Genre=GOSPEL_TEACHING_SAYING, Addressed=NOT_SPECIFIED, Responsible=INDIVIDUAL (John)
      - John 1:36 (John speaking to disciples - contains speech verb, αὐτοῖς refers to disciples): Genre=GOSPEL_TEACHING_SAYING, Addressed=DISCIPLES, Responsible=INDIVIDUAL (John)
      - John 1:38 (contains λέγει αὐτοῖς - "he says to them", Jesus speaking to two disciples): Genre=NARRATIVE (speech inside narration), Addressed=DISCIPLES (αὐτοῖς = "them" = two disciples), Responsible=INDIVIDUAL (Jesus - subject of λέγει)
      - John 1:41 (Andrew speaking to Simon - contains speech verb): Genre=GOSPEL_TEACHING_SAYING, Addressed=INDIVIDUAL, Responsible=INDIVIDUAL
      
      CRITICAL: All verses in John 1:1-18 (Prologue) are NARRATIVE, not GOSPEL_TEACHING_SAYING, because they are narrator statements describing events.
      
      CRITICAL DETECTION EXAMPLES:
      - Verse with "λέγει αὐτοῖς" → Check: Who is the subject of λέγει? (responsible_party) Who does αὐτοῖς refer to? (addressed_party)
      - Verse with "εἶπαν αὐτῷ" → Check: Who is the subject of εἶπαν? (responsible_party) Who does αὐτῷ refer to? (addressed_party)
      - Verse with no speech verb → responsible_party = NOT_SPECIFIED, addressed_party = NOT_SPECIFIED
      
      ✅ When to use NOT_SPECIFIED:
      Use NOT_SPECIFIED when:
      - The text is a narrator statement
      - The text is not directed to any person or group
      - The text is descriptive rather than instructive
      - Prophecies with no explicit audience
      - Truth statements (e.g., John 1:1, Genesis 1:1)
      - The speaker is not directly present (narrator)
      
      This keeps the data consistent and sortable without forcing interpretations.
      
      ⚠️ CRITICAL: All three fields (genre_code, addressed_party_code, responsible_party_code) are REQUIRED for every verse. Never leave any of them null. Use NOT_SPECIFIED when appropriate, but always assign a value.
      
      ================================================================================
      REMEMBER: 98% ACCURACY TARGET
      ================================================================================
      - Complete lexical coverage is the #1 priority
      - Missing any lexically valid meaning = INCOMPLETE
      - LSV translation must be built strictly from word-for-word chart
      - No theological or philosophical imports allowed
    PROMPT
  end

  def update_text_content(result)
    # Store word_for_word with lsv_notes as a structured object
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
    
    # Add party and genre fields - these are REQUIRED, so set defaults if missing
    update_params[:addressed_party_code] = result[:addressed_party_code].presence || 'NOT_SPECIFIED'
    update_params[:addressed_party_custom_name] = result[:addressed_party_custom_name] if result[:addressed_party_custom_name].present?
    update_params[:responsible_party_code] = result[:responsible_party_code].presence || 'NOT_SPECIFIED'
    update_params[:responsible_party_custom_name] = result[:responsible_party_custom_name] if result[:responsible_party_custom_name].present?
    
    # Genre is REQUIRED - if missing, log error but don't fail (will be caught by validation)
    if result[:genre_code].present?
      update_params[:genre_code] = result[:genre_code]
    else
      Rails.logger.error "WARNING: genre_code missing for #{@text_content.unit_key} - this is required!"
      # Don't set a default genre - validation should catch this
    end
    
    @text_content.update!(update_params)
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

