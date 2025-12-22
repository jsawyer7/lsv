module Verifaith
  module Validators
    # Universal grammar-level validator: prevents substantival/articular present participles
    # of εἰμί from being glossed as abstract nouns ("the being", "Being", etc.).
    # This is grammar-level, not verse-specific.
    class EimiParticipleReificationValidator
      # Forbidden standalone abstract noun renderings
      FORBIDDEN_STANDALONE = [
        'being',
        'the being',
        'Being',
        'The Being',
        'existent',
        'the existent',
        'Existent',
        'The Existent',
        'existing one',
        'the existing one',
        'Existing One',
        'The Existing One'
      ].freeze

      # Allowed relational/head forms (canonical house style)
      ALLOWED_RELATIONAL = [
        '(one) being',
        'one who is',
        '(one) existing',
        'being-one',
        'one-being'
      ].freeze

      # Canonical form (recommended for deterministic storage)
      CANONICAL_FORM = '(one) being'.freeze

      def initialize(word_for_word:, mode: :verify)
        @wfw = word_for_word || []
        @mode = mode.to_sym
      end

      def validate
        return ValidatorResult.ok unless @wfw.is_a?(Array) && @wfw.any?

        violations = []

        @wfw.each_with_index do |row, i|
          next unless row.is_a?(Hash)

          # Extract token data
          lemma = row['lemma'] || row[:lemma]
          base_gloss = row['base_gloss'] || row[:base_gloss]
          morphology = row['morphology'] || row[:morphology] || ''
          token = row['token'] || row[:token] || ''
          is_articular = row['is_articular'] || row[:is_articular]
          is_substantival = row['is_substantival'] || row[:is_substantival]

          # Skip if not εἰμί
          next unless lemma.to_s.strip.downcase == 'εἰμί' || lemma.to_s.strip.downcase == 'ειμι'

          # Check if present participle
          next unless is_present_participle?(morphology, row)

          # Check if substantival/articular
          prev_row = i > 0 ? (@wfw[i - 1] || {}) : nil
          next unless is_substantival_usage?(row, prev_row, is_articular, is_substantival)

          # Normalize base_gloss for comparison
          normalized_gloss = normalize_gloss(base_gloss.to_s)

          # Check for forbidden standalone forms
          if FORBIDDEN_STANDALONE.any? { |forbidden| normalized_gloss.downcase == forbidden.downcase }
            violations << {
              token: token,
              lemma: lemma,
              base_gloss: base_gloss,
              forbidden_form: normalized_gloss,
              suggestion: CANONICAL_FORM
            }
            next
          end

          # Check if using allowed relational form
          unless ALLOWED_RELATIONAL.any? { |allowed| normalized_gloss.downcase == allowed.downcase }
            violations << {
              token: token,
              lemma: lemma,
              base_gloss: base_gloss,
              issue: 'not_using_relational_form',
              suggestion: CANONICAL_FORM
            }
          end
        end

        return ValidatorResult.ok if violations.empty?

        # Build error message
        error_details = violations.map do |v|
          if v[:forbidden_form]
            "Token '#{v[:token]}' (εἰμί participle) uses forbidden abstract noun '#{v[:base_gloss]}'"
          else
            "Token '#{v[:token]}' (εἰμί participle) must use relational/head form; got '#{v[:base_gloss]}'"
          end
        end

        suggestion = "Use canonical form: '#{CANONICAL_FORM}' or one of: #{ALLOWED_RELATIONAL.join(', ')}"

        if @mode == :populate
          ValidatorResult.warn(
            warnings: "Substantival εἰμί present participle reification detected: #{error_details.join('; ')}. #{suggestion}",
            flags: ['WFW_EIMI_PARTICIPLE_REIFICATION'],
            meta: {
              violations: violations,
              suggestion: suggestion,
              repair_hint: "For substantival εἰμί present participles, never use abstract nouns like 'the being'. Always use relational/head form: '#{CANONICAL_FORM}'"
            }
          )
        else
          # :verify mode - hard fail
          ValidatorResult.fail(
            errors: "Substantival εἰμί present participle reification prohibited: #{error_details.join('; ')}. #{suggestion}",
            flags: ['WFW_EIMI_PARTICIPLE_REIFICATION'],
            meta: {
              violations: violations,
              suggestion: suggestion
            }
          )
        end
      end

      private

      def is_present_participle?(morphology, row)
        morph_str = morphology.to_s.downcase

        # Check morphology string for participle + present indicators
        # Common patterns: "participle present", "V-PNP", "part pres", etc.
        return true if morph_str.include?('participle') && morph_str.include?('present')
        return true if morph_str.match?(/v-?pnp/i)  # Verb-Participle-Present-Participle
        return true if morph_str.match?(/part.*pres|pres.*part/i)

        # Check explicit fields if available
        pos = row['pos'] || row[:pos]
        tense = row['tense'] || row[:tense]

        return true if pos.to_s.downcase == 'participle' && tense.to_s.downcase == 'present'

        false
      end

      def is_substantival_usage?(row, prev_row, is_articular, is_substantival)
        # Use explicit flags if available
        return true if is_substantival == true
        return true if is_articular == true

        # Fallback: check if previous token is an article
        return false unless prev_row

        prev_lemma = prev_row['lemma'] || prev_row[:lemma]
        prev_pos = prev_row['pos'] || prev_row[:pos]
        prev_morphology = prev_row['morphology'] || prev_row[:morphology] || ''

        # Check if previous token is an article (ὁ, ἡ, τό)
        article_lemmas = ['ὁ', 'ἡ', 'τό', 'ο', 'η', 'το']
        return true if article_lemmas.include?(prev_lemma.to_s.strip.downcase)

        # Check morphology for article
        prev_morph_str = prev_morphology.to_s.downcase
        return true if prev_morph_str.include?('article') || prev_pos.to_s.downcase == 'article'

        false
      end

      def normalize_gloss(gloss)
        # Normalize whitespace and trim
        gloss.strip.split(/\s+/).join(' ')
      end
    end
  end
end

