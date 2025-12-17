module Verifaith
  module Validators
    class GreekNoSmoothingValidator
      # Heuristic patterns for stative / existential frames
      STATIVE_LEMMA_HINTS = [
        /(?:\bἐστίν\b|\bἐστι\b|\bἦν\b|\bεἰμί\b|\bὑπάρχ\w+\b|\bμέν\w+\b|\bκάθη\w+\b|\bκεῖ\w+\b|\bγίν\w+\b)/i
      ].freeze

      # Very tight locative noun allowlist (can be expanded later)
      EIS_LOCATIVE_NOUNS = %w[
        κόλπον κόλπος
        αἰῶνα αἰών
      ].freeze

      def initialize(source:, source_text:, word_for_word:, lsv_literal_reconstruction:)
        @source = source
        @src = source_text.to_s
        @wfw = word_for_word || []
        @lsv = lsv_literal_reconstruction.to_s
        @sc = SourceClassifier.new(source)
      end

      def validate
        return ValidatorResult.ok unless @sc.greek?

        result = ValidatorResult.ok
        result.merge!(validate_logos_capitalization)
        result.merge!(validate_demonstratives)
        result.merge!(validate_imperfect_aspect_hint)
        result.merge!(validate_eis_stative_rule_token_following)
        result
      end

      private

      def validate_logos_capitalization
        bad = []

        @wfw.each do |row|
          next unless row.is_a?(Hash)

          tok = (row['token'] || row[:token]).to_s
          lemma = (row['lemma'] || row[:lemma]).to_s
          base = (row['base_gloss'] || row[:base_gloss]).to_s

          if lemma.downcase == 'λόγος' || tok.include?('λόγος')
            bad << "logos base_gloss must be 'word' lowercase; got '#{base}'" if base.strip == 'Word'
          end
        end

        if bad.any?
          ValidatorResult.fail(errors: bad, flags: ['GREEK_SMOOTHING_LOGOS'])
        else
          ValidatorResult.ok
        end
      end

      def validate_demonstratives
        bad = []

        @wfw.each do |row|
          next unless row.is_a?(Hash)
          tok = (row['token'] || row[:token]).to_s
          base = (row['base_gloss'] || row[:base_gloss]).to_s

          next unless tok.match?(/\bοὗτος\b|\bαὕτη\b|\bτοῦτο\b/i)
          next if base.downcase.start_with?('this')

          bad << "Demonstrative #{tok} base_gloss must be 'this' or 'this one', got '#{base}'"
        end

        if bad.any?
          ValidatorResult.fail(errors: bad, flags: ['GREEK_SMOOTHING_DEMONSTRATIVE'])
        else
          ValidatorResult.ok
        end
      end

      def validate_imperfect_aspect_hint
        return ValidatorResult.ok unless @wfw.any? { |r| (r['token'] || r[:token]).to_s == 'ἦν' }

        row = @wfw.find { |r| (r['token'] || r[:token]).to_s == 'ἦν' }
        base = (row['base_gloss'] || row[:base_gloss]).to_s.downcase

        if base == 'was'
          ValidatorResult.warn(
            warnings: "Imperfect ἦν base_gloss is 'was' (aspect lost). Prefer 'was-being' or aspect-aware gloss.",
            flags: ['GREEK_IMPERFECT_ASPECT_WEAK']
          )
        else
          ValidatorResult.ok
        end
      end

      # εἰς + locative noun rule with tight allowlist and WFW awareness
      def validate_eis_stative_rule_token_following
        return ValidatorResult.ok unless @src.include?('εἰς')
        return ValidatorResult.ok unless @lsv.downcase.include?(' into ')
        return ValidatorResult.ok unless @wfw.is_a?(Array) && @wfw.any?

        tokens = @wfw.map { |r| (r['token'] || r[:token]).to_s }.reject(&:empty?)
        return ValidatorResult.ok if tokens.empty?

        tokens.each_with_index do |t, i|
          next unless t == 'εἰς'
          nxt = tokens[i + 1].to_s
          next if nxt.empty?

          if EIS_LOCATIVE_NOUNS.include?(nxt) && @lsv.downcase.include?(' into ')
            return ValidatorResult.fail(
              errors: "εἰς + locative noun smoothing: token after εἰς is '#{nxt}', but LSV uses 'into' (prefer 'in' here).",
              flags: ['GREEK_EIS_LOCATIVE_INTO'],
              meta: { eis_next_token: nxt }
            )
          end
        end

        # Optionally, we can keep a broader heuristic as a warning only
        if STATIVE_LEMMA_HINTS.any? { |re| re.match?(@src) } && @lsv.downcase.include?(' into ')
          return ValidatorResult.warn(
            warnings: 'Potential εἰς + stative frame smoothing: consider locative "in" instead of directional "into".',
            flags: ['GREEK_EIS_STATIVE_INTO_CAUTIOUS']
          )
        end

        ValidatorResult.ok
      end
    end
  end
end



