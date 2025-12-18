module Verifaith
  module Validators
    class PunctuationBoundaryValidator
      # Greek punctuation marks that create boundaries
      GREEK_PUNCTUATION = /[·,.;:!?«»"ʼ'()\[\]{}]/.freeze

      def initialize(source_text:, lsv_literal_reconstruction:)
        @source_text = source_text.to_s
        @lsv = lsv_literal_reconstruction.to_s
      end

      def validate
        return ValidatorResult.ok if @source_text.strip.empty? || @lsv.strip.empty?

        # Extract punctuation sequence from Greek source
        source_punct = extract_punctuation_sequence(@source_text)

        # Extract comma boundaries from LSV (commas are the main boundary marker in English)
        lsv_commas = @lsv.scan(/,/).count

        # Count commas in Greek (if any)
        source_commas = @source_text.scan(/,/).count

        # If LSV has more commas than Greek, we may have invented boundaries
        # Allow some flexibility (e.g., appositional chains might need commas for clarity)
        # But flag if there's a significant mismatch
        if lsv_commas > source_commas + 2 # Allow up to 2 extra commas for English clarity
          # Check if the extra commas are in suspicious contexts (title chains, apposition)
          suspicious_patterns = [
            /\b[A-Z][a-z]+\s*,\s*[A-Z][a-z]+\s*,\s*[A-Z][a-z]+/i, # Title case chains
            /\bthe\s+[\w-]+\s*,\s*the\s+[\w-]+\s*,\s*the\s+[\w-]+/i # "the X, the Y, the Z" chains
          ]

          suspicious_found = suspicious_patterns.any? { |pattern| @lsv.match?(pattern) }

          if suspicious_found
            return ValidatorResult.fail(
              errors: "LSV introduces comma boundaries not present in Greek punctuation. Greek commas: #{source_commas}, LSV commas: #{lsv_commas}",
              flags: ['LSV_PUNCTUATION_INVENTED'],
              meta: {
                source_commas: source_commas,
                lsv_commas: lsv_commas,
                source_punctuation_sequence: source_punct
              }
            )
          end
        end

        ValidatorResult.ok
      end

      private

      def extract_punctuation_sequence(text)
        text.scan(GREEK_PUNCTUATION).join('')
      end
    end
  end
end

