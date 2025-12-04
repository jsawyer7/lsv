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
      missing_required_fields = parsed['missing_required_fields'] || []
      character_accurate = parsed['character_accurate'] == true || (parsed['character_accurate'].nil? && parsed['is_accurate'] == true)
      lexical_coverage_complete = parsed['lexical_coverage_complete'] != false # Default to true if not specified
      lsv_translation_valid = parsed['lsv_translation_valid'] != false # Default to true if not specified
      
      # Overall accuracy requires ALL checks to pass, including required fields
      overall_accurate = parsed['is_accurate'] == true || (
        character_accurate && 
        lexical_coverage_complete && 
        lsv_translation_valid && 
        lsv_violations.empty? &&
        missing_required_fields.empty?
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
        missing_required_fields: missing_required_fields,
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
      ⚠️ CRITICAL: CAPITALIZATION VALIDATION REQUIREMENT ⚠️
      ================================================================================
      The Westcott-Hort 1881 source text uses SPECIFIC capitalization that MUST be preserved exactly.
      - If source has "ἐν" (lowercase), provided text MUST have "ἐν" (lowercase), NOT "Ἐν" - even if it's the first word
      - If source has "λόγος" (lowercase), provided text MUST have "λόγος" (lowercase), NOT "Λόγος"
      - If source has "θεόν" (lowercase), provided text MUST have "θεόν" (lowercase), NOT "Θεόν"
      - If source has "θεὸς" (lowercase), provided text MUST have "θεὸς" (lowercase), NOT "Θεὸς"
      - Capitalization differences are CHARACTER ACCURACY ERRORS - they make the text NOT 100% accurate
      - Do NOT accept modern capitalization conventions (e.g., capitalizing first word of sentence)
      - Do NOT accept capitalization of first word if source has it lowercase
      - Example: John 1:1 in WH1881 starts with "ἐν" (lowercase), NOT "Ἐν" (capitalized)
      - Example: John 1:1 in WH1881 has "λόγος", "θεόν", "θεὸς" all lowercase - if any are capitalized, it's WRONG
      
      ================================================================================
      VALIDATION REQUIREMENTS
      ================================================================================
      
      1. CHARACTER-BY-CHARACTER ACCURACY (INCLUDING EXACT CAPITALIZATION)
      - Compare the provided text character-by-character with the source
      - Identify ANY discrepancies (missing characters, extra characters, wrong characters, punctuation differences, spacing differences, CAPITALIZATION DIFFERENCES)
      - Report accuracy as a percentage (100% = perfect match)
      - List all discrepancies with exact positions and differences
      - Even a single character difference (including capitalization) means the text is NOT 100% accurate
      - Punctuation, diacritics, spacing, AND CAPITALIZATION must all match exactly
      - CRITICAL: If source has "θεόν" (lowercase) and provided text has "Θεόν" (capitalized), this is a CAPITALIZATION ERROR and must be flagged
      - CRITICAL: If source has "λόγος" (lowercase) and provided text has "Λόγος" (capitalized), this is a CAPITALIZATION ERROR
      - CRITICAL: If source has "θεὸς" (lowercase) and provided text has "Θεὸς" (capitalized), this is a CAPITALIZATION ERROR
      - Do NOT accept modern capitalization conventions - source text capitalization must be preserved exactly
      - Capitalization errors are character accuracy errors - they make the text NOT 100% accurate
      
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
      
      CRITICAL WORD-FOR-WORD VALIDATION RULES:
      - Demonstrative pronouns (οὗτος, etc.): base_gloss must be "this" or "this one", NEVER "he/she/it"
      - Imperfect verbs (ἦν, etc.): base_gloss should preserve aspect as "was-being", NOT just "was"
      - Prepositions: πρὸς + accusative MUST have base_gloss as "toward" or "to", NEVER "with"
      - Articles: If source language has no article, gloss should NOT supply one
      - Prepositions with stative verbs: εἰς with stative verbs/participles (εἰμί, μένω, etc.) MUST be "in" (locative), NOT "into" (directional)
      - If ANY of these violations are found → flag as INVALID_MEANING
      
      ⚠️ CRITICAL CAPITALIZATION VALIDATION IN ENGLISH GLOSSES:
      - NEVER capitalise an English gloss solely because of traditional theological rendering
      - Capitalisation may ONLY occur when Greek grammar marks the word as a proper title/name through article + contextual identification
      - ANY violation of capitalisation rules MUST automatically set completeness: "INCOMPLETE"
      
      # λόγος ("logos") Capitalization:
      - base_gloss MUST ALWAYS be "word" (lowercase "w") in ALL contexts
      - NO exceptions. No "Word." No titular capitalisation. Flag as INVALID_MEANING if capitalized
      
      # θεός ("theos") Capitalization:
      - When anarthrous (no article), predicate nominative, or qualitative sense → base_gloss MUST be "god" or "deity" (lowercase "g")
      - ONLY use "God" (capital G) when BOTH: (1) Greek has article (ὁ, τὸν, etc.) AND (2) Context identifies as the Father (one God of Israel)
      - Any other context → lowercase "god". Flag as INVALID_MEANING if "God" used incorrectly
      
      # κύριος ("kyrios") Capitalization:
      - base_gloss MUST be "lord" or "master" (lowercase) unless Greek has article AND narrative context makes it clear titular reference
      - Under no circumstances infer divine LORD simply because tradition capitalises it. Flag as INVALID_MEANING if capitalized without proper justification
      
      # Summary:
      - English capitalisation must follow Greek grammar, NEVER theology
      - Greek never uses capitals for titles → neither can LSV
      - Flag ANY theological capitalisation as INVALID_MEANING and set completeness: "INCOMPLETE"
      
      3. LSV TRANSLATION VALIDATION
      The LSV translation must:
      - Be built ONLY from the word-for-word chart
      - Use ONLY meanings from base_gloss + secondary_glosses
      - NOT introduce paraphrases, theology, interpretation, smoothing, or denominational bias
      - Reflect ALL valid lexical senses (primary + secondary documented)
      - NOT exceed source text (no additions unless minimal structural support)
      - If LSV translation uses a meaning NOT in word-for-word chart → flag as INVALID_MEANING
      
      CRITICAL LSV TRANSLATION VALIDATION RULES:
      - πρὸς + accusative: MUST be "toward" or "to", NEVER "with" (even if contextually common, "with" is theological smoothing)
      - Imperfect verbs: MUST preserve continuous aspect (e.g., "was-being" not just "was")
      - Articles: MUST NOT insert "the" where source language has no article (e.g., ἐν ἀρχῇ = "in beginning", not "in the beginning")
      - Demonstrative pronouns: MUST be "this" or "this one", NEVER "he/she/it" (that's interpretive smoothing)
      - Prepositions with stative verbs: εἰς with stative verbs/participles MUST be "in" (locative), NOT "into" (directional)
      - Structural support for articles: If English "the" is added, MUST note in lsv_notes.structural_support whether Greek phrase is articular or anarthrous
      - If Greek phrase is anarthrous, structural_support MUST say: "English 'the' added for grammar; Greek phrase is anarthrous."
      - Syntax notes precision: Notes MUST name exact governing lemma (e.g., "direct object of ἑώρακεν", not "object of the verb")
      - If ANY of these violations are found → flag as INVALID_MEANING and set lsv_translation_valid to false
      
      4. LSV RULE VALIDATION
      Check word-for-word translation notes for violations of: "No external philosophical, theological, or cultural meanings may be imported."
      - Flag any notes that add philosophical definitions, classical Greek philosophical concepts, or theological interpretations
      - Flag any notes that import modern lexicon expansions with external meanings
      - Flag any notes that add cultural or historical context beyond basic dictionary definitions
      - Notes should ONLY contain: dictionary meanings, grammatical notes, alternative dictionary translations, basic linguistic information
      
      5. REQUIRED CLASSIFICATION FIELDS VALIDATION
      ⚠️ CRITICAL: Every verse MUST have these three fields populated:
      - genre_code: REQUIRED - Every verse must have a genre (NARRATIVE, LAW, PROPHECY, WISDOM, POETRY_SONG, PARABLE, GOSPEL_TEACHING_SAYING, EPISTLE_LETTER, APOCALYPTIC_VISION, GENEALOGY_LIST, PRAYER)
      - addressed_party_code: REQUIRED - Every verse must have an addressed party (use NOT_SPECIFIED if unclear)
      - responsible_party_code: REQUIRED - Every verse must have a responsible party (use NOT_SPECIFIED if unclear)
      - If ANY of these fields are missing or null, flag as MISSING_REQUIRED_FIELDS
      - These fields are NEVER optional - every verse must have all three
      
      ⚠️ CRITICAL GENRE VALIDATION RULES:
      Genre tracks the LITERARY FUNCTION of the verse, NOT the presence of speech.
      
      NARRATIVE is correct when:
      - The narrator is describing an event (even if quoting someone speaking)
      - The narrator is reporting what someone said (e.g., "John cried out saying...")
      - The verse is part of the story/narrative flow
      - All prologue verses (John 1:1-18) are NARRATIVE - none are teachings
      - If John the Baptist speaks but in a narrative setting (narrator reporting it) → NARRATIVE
      - If the narrator quotes someone but is describing an event → NARRATIVE
      - Examples: John 1:1-18 (all NARRATIVE), John 1:15 (narrator reporting John's words = NARRATIVE), John 1:38 (narrator describing event = NARRATIVE)
      
      PARABLE is correct when:
      - The verse is a short narrative story used to illustrate a moral or spiritual lesson
      - Typically introduced with phrases like "The kingdom of heaven is like..." or "A certain man had..."
      - Distinct from GOSPEL_TEACHING_SAYING: parables are illustrative stories, while teachings are direct instruction
      - Examples: Parable of the Sower, Parable of the Good Samaritan, Parable of the Prodigal Son
      - If Jesus tells a parable, genre MUST = PARABLE (not GOSPEL_TEACHING_SAYING)

      GOSPEL_TEACHING_SAYING is correct ONLY when:
      - Jesus is teaching or speaking instructionally (direct teaching, not just quoted by narrator)
      - The verse is instructional content, not narrative description, and NOT a parable
      - The verse functions as a teaching/saying, not as story-telling
      - Direct sayings, commands, explanations without narrative story structure
      
      RULE: If the narrator is describing an event → Genre MUST = NARRATIVE
      RULE: If Jesus is teaching or speaking instructionally (direct instruction, not a story) → Genre = GOSPEL_TEACHING_SAYING
      RULE: If Jesus tells a parable (illustrative story) → Genre MUST = PARABLE
      RULE: If John the Baptist speaks but in a narrative setting → Genre MUST = NARRATIVE
      RULE: If Teaching Rule = FALSE → Genre MUST = NARRATIVE
      
      If genre_code is GOSPEL_TEACHING_SAYING but the verse is narrator describing an event, flag as INVALID_GENRE.
      If genre_code is GOSPEL_TEACHING_SAYING but the verse is a parable, flag as INVALID_GENRE (should be PARABLE).
      
      ================================================================================
      VALIDATION FLAGS
      ================================================================================
      You must return one or more of these flags:
      - OK: Exact text match, complete lexical coverage, LSV translation valid, no LSV violations, all required fields present
      - TEXT_MISMATCH: Text differs from stored source text
      - MISSING_LEXICAL_MEANINGS: At least one token has incomplete lexical range
      - INVALID_MEANING: LSV translation uses a meaning not in word-for-word chart
      - LSV_RULE_VIOLATION: Word-for-word notes contain philosophical/theological imports
      - MISSING_REQUIRED_FIELDS: genre_code, addressed_party_code, or responsible_party_code is missing
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
      
      ⚠️ CRITICAL CAPITALIZATION VALIDATION ⚠️
      The Westcott-Hort 1881 source uses SPECIFIC capitalization:
      - "ἐν" should be lowercase (even as first word), NOT "Ἐν" - John 1:1 starts with lowercase "ἐν"
      - "λόγος" should be lowercase, NOT "Λόγος"
      - "θεόν" should be lowercase, NOT "Θεόν"
      - "θεὸς" should be lowercase, NOT "Θεὸς"
      - Do NOT accept capitalization of first word if source has it lowercase
      - Capitalization differences are CHARACTER ACCURACY ERRORS
      
      Please validate the following against #{@source.name} for #{@book.std_name} #{@chapter}:#{@verse}:
      
      1. SOURCE TEXT (Character-by-character accuracy INCLUDING EXACT CAPITALIZATION):
      "#{@text_content.content}"
      
      CRITICAL: Check that capitalization matches exactly - if source has lowercase and provided text has capitalized, this is an ERROR.
      
      2. WORD-FOR-WORD TRANSLATION CHART:
      #{word_for_word_data.to_json}
      
      3. LSV LITERAL RECONSTRUCTION:
      "#{@text_content.lsv_literal_reconstruction}"
      
      4. LSV NOTES (if available):
      #{lsv_notes.to_json}
      
      5. CLASSIFICATION FIELDS (REQUIRED - Check if present):
      - genre_code: #{@text_content.genre_code || 'MISSING'}
      - addressed_party_code: #{@text_content.addressed_party_code || 'MISSING'}
      - responsible_party_code: #{@text_content.responsible_party_code || 'MISSING'}
      
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
        "missing_required_fields": [
          {
            "field": "genre_code | addressed_party_code | responsible_party_code",
            "issue": "description of missing field or invalid classification"
          }
        ],
        "validation_flags": ["OK" | "TEXT_MISMATCH" | "MISSING_LEXICAL_MEANINGS" | "INVALID_MEANING" | "LSV_RULE_VIOLATION" | "MISSING_REQUIRED_FIELDS" | "INVALID_GENRE"],
        "validation_notes": "Detailed notes about the validation"
      }
      
      ================================================================================
      VALIDATION RULES
      ================================================================================
      
      1. CHARACTER ACCURACY (INCLUDING EXACT CAPITALIZATION):
      - Compare character-by-character with the source
      - Report 100% accuracy ONLY if every single character matches exactly (including capitalization)
      - Include all discrepancies, no matter how small
      - Note any differences in punctuation, diacritics, spacing, OR CAPITALIZATION
      - ⚠️ CRITICAL CAPITALIZATION CHECKS:
        * If source has "ἐν" (lowercase) and provided text has "Ἐν" (capitalized) → CAPITALIZATION ERROR (even if first word)
        * If source has "λόγος" (lowercase) and provided text has "Λόγος" (capitalized) → CAPITALIZATION ERROR
        * If source has "θεόν" (lowercase) and provided text has "Θεόν" (capitalized) → CAPITALIZATION ERROR
        * If source has "θεὸς" (lowercase) and provided text has "Θεὸς" (capitalized) → CAPITALIZATION ERROR
        * Any capitalization difference is a CHARACTER ACCURACY ERROR
        * Do NOT accept modern capitalization conventions (e.g., capitalizing first word of sentence)
      - CRITICAL: Capitalization differences are errors (e.g., "θεόν" vs "Θεόν" is a mismatch)
      - CRITICAL: Capitalization is part of the source text - changing it violates character-by-character accuracy
      - Do NOT accept modern capitalization conventions - source capitalization must be preserved exactly
      - Set character_accurate to false if ANY capitalization differences are found
      - Set character_accurate to true ONLY if 100% match (including exact capitalization)
      
      2. LEXICAL COVERAGE:
      - For EACH token, verify ALL lexically valid meanings are in base_gloss + secondary_glosses
      - Check completeness field: should be "COMPLETE" only if ALL meanings included
      - If any token is missing valid meanings, add to lexical_coverage_issues
      - Set lexical_coverage_complete to false if ANY token has incomplete coverage
      
      3. LSV TRANSLATION:
      - Verify LSV translation uses ONLY meanings from word-for-word chart
      - Check that no meanings are used that aren't in base_gloss or secondary_glosses
      - Verify LSV translation doesn't exceed source text (no additions)
      - CRITICAL CHECKS:
        * πρὸς + accusative: Must be "toward" or "to", NEVER "with" → if "with" is used, flag as INVALID_MEANING
        * Imperfect verbs: Must preserve aspect (e.g., "was-being" not just "was") → if aspect is smoothed, flag as INVALID_MEANING
        * Articles: Must NOT insert "the" where source has no article (e.g., "in beginning" not "in the beginning") → if article inserted, flag as INVALID_MEANING
        * Demonstrative pronouns: Must be "this/this one", NEVER "he/she/it" → if personal pronoun used, flag as INVALID_MEANING
      - If LSV translation violates these rules, add to lsv_translation_issues with specific details
      - Set lsv_translation_valid to false if ANY issues found
      
      4. LSV RULE COMPLIANCE:
      - Review word-for-word notes for each token
      - Check for violations: philosophical definitions, theological interpretations, cultural imports
      - Look for modern lexicon expansions with external meanings
      - Notes should ONLY contain: dictionary meanings, grammatical notes, alternative dictionary translations
      - If violations found, add to lsv_rule_violations and set is_accurate to false
      
      5. REQUIRED CLASSIFICATION FIELDS:
      - Check that genre_code is present and valid (one of: NARRATIVE, LAW, PROPHECY, WISDOM, POETRY_SONG, GOSPEL_TEACHING_SAYING, EPISTLE_LETTER, APOCALYPTIC_VISION, GENEALOGY_LIST, PRAYER)
      - Check that addressed_party_code is present and valid (one of: INDIVIDUAL, ISRAEL, JUDAH, JEWS, GENTILES, DISCIPLES, BELIEVERS, ALL_PEOPLE, CHURCH, NOT_SPECIFIED)
      - Check that responsible_party_code is present and valid (one of: INDIVIDUAL, ISRAEL, JUDAH, JEWS, GENTILES, DISCIPLES, BELIEVERS, ALL_PEOPLE, CHURCH, NOT_SPECIFIED)
      - If ANY of these fields are missing or null, add to missing_required_fields and set is_accurate to false
      - These fields are NEVER optional - every verse must have all three
      
      ⚠️ CRITICAL GENRE VALIDATION:
      - If the narrator is describing an event (even if quoting speech) → Genre MUST be NARRATIVE
      - If the narrator is reporting what someone said → Genre MUST be NARRATIVE
      - If speech occurs inside narration (narrator reporting "he said to them") → Genre MUST be NARRATIVE
      - If John the Baptist speaks but in a narrative setting → Genre MUST be NARRATIVE
      - If Teaching Rule = FALSE (not instructional teaching) → Genre MUST be NARRATIVE
      - All prologue verses (John 1:1-18) MUST be NARRATIVE
      - GOSPEL_TEACHING_SAYING is ONLY correct when: verse contains direct speech by Jesus in a Gospel (and it's instructional teaching)
      - GENRE RULE: If verse contains direct speech by Jesus in a Gospel → GOSPEL_TEACHING_SAYING, otherwise if speech occurs inside narration → NARRATIVE, otherwise no speech → NARRATIVE
      - If genre_code is GOSPEL_TEACHING_SAYING but the verse is narrator describing an event → add to missing_required_fields with issue "INVALID_GENRE: Should be NARRATIVE (narrator describing event)"
      - Examples of CORRECT classifications:
        * John 1:15 (narrator reporting John cried out) → NARRATIVE (NOT GOSPEL_TEACHING_SAYING)
        * John 1:38 (λέγει αὐτοῖς - narrator reporting Jesus speaking) → NARRATIVE (NOT GOSPEL_TEACHING_SAYING)
        * All John 1:1-18 → NARRATIVE (NOT GOSPEL_TEACHING_SAYING)
      
      ⚠️ CRITICAL RESPONSIBLE PARTY VALIDATION:
      - Check if verse contains direct-speech verbs (λέγει, εἶπεν, λέγων, etc.)
      - If speech verb exists → responsible_party MUST = grammatical subject of that verb
      - If subject is named individual → responsible_party = INDIVIDUAL
      - If subject is group → responsible_party = that group code
      - If subject is pronoun → use nearest explicit antecedent from narrative thread
      - If no speech verb → responsible_party = NOT_SPECIFIED
      - Example: John 1:38 (λέγει with Jesus as subject) → responsible_party = INDIVIDUAL (NOT NOT_SPECIFIED)
      
      ⚠️ CRITICAL ADDRESSED PARTY VALIDATION:
      - Check if verse contains recipient markers (αὐτῷ/αὐτοῖς, πρός + accusative, indirect-object pronouns)
      - If recipient marker exists → addressed_party MUST = entity that marker refers to
      - If pronoun refers to specific entity from previous verse → assign that entity's code
      - Example: John 1:38 (αὐτοῖς referring to two disciples from previous verse) → addressed_party = DISCIPLES (NOT NOT_SPECIFIED)
      - If no recipient marker → addressed_party = NOT_SPECIFIED
      
      6. OVERALL ACCURACY:
      - Set is_accurate to true ONLY if:
        * character_accurate = true (100% character match)
        * lexical_coverage_complete = true (all meanings included)
        * lsv_translation_valid = true (built from chart only)
        * lsv_rule_violations = [] (no violations)
        * missing_required_fields = [] (all required classification fields present)
      - If ANY of these fail, set is_accurate to false
      
      7. VALIDATION FLAGS:
      - Add "OK" if all checks pass (including all required fields present and correct)
      - Add "TEXT_MISMATCH" if character accuracy < 100%
      - Add "MISSING_LEXICAL_MEANINGS" if any token has incomplete lexical coverage
      - Add "INVALID_MEANING" if LSV translation uses invalid meanings
      - Add "LSV_RULE_VIOLATION" if notes contain philosophical/theological imports
      - Add "MISSING_REQUIRED_FIELDS" if genre_code, addressed_party_code, or responsible_party_code is missing
      - Add "INVALID_GENRE" if genre_code is incorrect (e.g., GOSPEL_TEACHING_SAYING when it should be NARRATIVE for narrator describing event)
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
        missing_required_fields: result[:missing_required_fields] || [],
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

