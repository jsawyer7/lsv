module Verifaith
  module Validators
    class WordForWordTokenPresenceValidator
      def initialize(source:, source_text:, word_for_word:)
        @source = source
        @source_text = source_text.to_s
        @wfw = word_for_word || []
      end

      def validate
        return ValidatorResult.fail(errors: 'source_text missing', flags: ['SOURCE_TEXT_MISSING']) if @source_text.strip.empty?
        return ValidatorResult.fail(errors: 'word_for_word missing', flags: ['WFW_MISSING']) unless @wfw.is_a?(Array) && @wfw.any?

        src_norm = PunctuationProfiles.normalize(@source_text, source: @source)
        missing = []

        @wfw.each do |row|
          next unless row.is_a?(Hash)

          tok = row['token'] || row[:token]
          next if tok.to_s.strip.empty?

          tok_norm = PunctuationProfiles.normalize(tok, source: @source)
          missing << tok if tok_norm.present? && !src_norm.include?(tok_norm)
        end

        if missing.any?
          ValidatorResult.fail(
            errors: "Word-for-word contains tokens not present in source_text: #{missing.uniq.join(', ')}",
            flags: ['WFW_TOKEN_NOT_IN_SOURCE'],
            meta: { missing_tokens: missing.uniq }
          )
        else
          ValidatorResult.ok
        end
      end
    end
  end
end



