module Verifaith
  module Validators
    class LsvFromChartValidator
      def initialize(source_text:, word_for_word:, lsv_literal_reconstruction:)
        @src = source_text.to_s
        @wfw = word_for_word || []
        @lsv = lsv_literal_reconstruction.to_s
      end

      def validate
        return ValidatorResult.fail(errors: 'lsv_literal_reconstruction missing', flags: ['LSV_MISSING']) if @lsv.strip.empty?
        return ValidatorResult.fail(errors: 'word_for_word missing', flags: ['WFW_MISSING']) unless @wfw.is_a?(Array) && @wfw.any?

        missing = []

        @wfw.each do |row|
          next unless row.is_a?(Hash)
          tok = row['token'] || row[:token]
          base = row['base_gloss'] || row[:base_gloss]

          missing << tok if tok.to_s.strip.present? && base.to_s.strip.empty?
        end

        if missing.any?
          return ValidatorResult.fail(
            errors: "word_for_word missing base_gloss for tokens: #{missing.join(', ')}",
            flags: ['WFW_BASE_GLOSS_MISSING']
          )
        end

        ValidatorResult.ok
      end
    end
  end
end

