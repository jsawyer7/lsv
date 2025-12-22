module Verifaith
  module Validators
    # Universal renderer guard: prevents substantival participle nominalizations
    # from appearing in Phase-2 (LSV) output, even if token table is "okay".
    # This catches regressions that slip through during string assembly.
    class SubstantivalParticipleNominalizationValidator
      # Banned nominalizations that should not appear in LSV
      BANNED_NOMINALIZATIONS = [
        /\bthe\s+being\b/i,
        /\bthe\s+existing\b/i,
        /\bthe\s+having\b/i,
        /\bthe\s+doing\b/i,
        /\bthe\s+making\b/i,
        /\bthe\s+going\b/i,
        /\bthe\s+coming\b/i,
        /\bthe\s+saying\b/i,
        /\bthe\s+speaking\b/i
      ].freeze

      # Universal renderer guard: forbidden phrases in Phase-2 output
      # These catch regressions even if token table is correct
      FORBIDDEN_PHRASES = [
        /\bthe\s+being\b/i,
        /\bThe\s+being\b/,
        /\bThe\s+Being\b/,
        /\bBeing\b(?=[\s\.;,]|$)/i  # Standalone "Being" at end or before punctuation
      ].freeze

      # Preferred format patterns (one-<gloss> or <gloss>-one)
      PREFERRED_PATTERNS = [
        /\bone-[\w-]+\b/i,  # one-being, one-having, etc.
        /\b[\w-]+-one\b/i  # being-one, having-one, etc.
      ].freeze

      def initialize(lsv_literal_reconstruction:, mode: :verify)
        @lsv = lsv_literal_reconstruction.to_s
        @mode = mode.to_sym
      end

      def validate
        return ValidatorResult.ok if @lsv.strip.empty?

        # PHASE 1: Check for banned nominalizations (general pattern matching)
        banned_found = []
        BANNED_NOMINALIZATIONS.each do |pattern|
          if @lsv.match?(pattern)
            match = @lsv.match(pattern)
            banned_found << match[0] if match
          end
        end

        # PHASE 2: Universal renderer guard (catches regressions in Phase-2 output)
        # This is specifically for εἰμί participle reification but applies universally
        renderer_guard_violations = []
        FORBIDDEN_PHRASES.each do |pattern|
          if @lsv.match?(pattern)
            match = @lsv.match(pattern)
            renderer_guard_violations << match[0] if match
          end
        end

        # Combine violations
        all_violations = (banned_found + renderer_guard_violations).uniq

        if all_violations.any?
          suggestion = 'Use "one-<gloss>" or "<gloss>-one" format instead (e.g., "the being" → "the being-one" or "one-being"). For substantival εἰμί participles, use "(one) being" or "one who is".'
          
          # Mode-based severity: warn in populate, fail in verify
          if @mode == :populate
            return ValidatorResult.warn(
              warnings: "Substantival participle nominalization detected: #{all_violations.join(', ')}. #{suggestion}",
              flags: ['LSV_SUBSTANTIVAL_PARTICIPLE_NOMINALIZATION'],
              meta: {
                detected_nominalizations: all_violations,
                suggestion: suggestion,
                repair_hint: "Never output '#{all_violations.first}'; output '#{all_violations.first.gsub(/\bthe\s+(\w+)\b/i, 'the \1-one')}' or 'one-\1' instead. For εἰμί participles, use '(one) being'."
              }
            )
          else
            # :verify mode - hard fail
            return ValidatorResult.fail(
              errors: "Substantival participle nominalization detected: #{all_violations.join(', ')}. #{suggestion}",
              flags: ['LSV_SUBSTANTIVAL_PARTICIPLE_NOMINALIZATION'],
              meta: {
                detected_nominalizations: all_violations,
                suggestion: suggestion
              }
            )
          end
        end

        ValidatorResult.ok
      end
    end
  end
end

