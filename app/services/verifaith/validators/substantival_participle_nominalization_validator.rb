module Verifaith
  module Validators
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

      # Preferred format patterns (one-<gloss> or <gloss>-one)
      PREFERRED_PATTERNS = [
        /\bone-[\w-]+\b/i,  # one-being, one-having, etc.
        /\b[\w-]+-one\b/i  # being-one, having-one, etc.
      ].freeze

      def initialize(lsv_literal_reconstruction:)
        @lsv = lsv_literal_reconstruction.to_s
      end

      def validate
        return ValidatorResult.ok if @lsv.strip.empty?

        # Check for banned nominalizations
        banned_found = []
        BANNED_NOMINALIZATIONS.each do |pattern|
          if @lsv.match?(pattern)
            match = @lsv.match(pattern)
            banned_found << match[0] if match
          end
        end

        if banned_found.any?
          return ValidatorResult.fail(
            errors: "Substantival participle nominalization detected: #{banned_found.join(', ')}",
            flags: ['LSV_SUBSTANTIVAL_PARTICIPLE_NOMINALIZATION'],
            meta: {
              detected_nominalizations: banned_found,
              suggestion: 'Use "one-<gloss>" or "<gloss>-one" format instead'
            }
          )
        end

        ValidatorResult.ok
      end
    end
  end
end

