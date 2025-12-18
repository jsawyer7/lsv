module Verifaith
  module Validators
    class UnitIdentityValidator
      def initialize(text_content:, source_text:, word_for_word:)
        @tc = text_content
        @source_text = source_text.to_s
        @wfw = word_for_word || []
      end

      def validate
        # Normalize and hash
        text_hash = GreekNormalizer.hash_text(@source_text)
        token_hash = GreekNormalizer.hash_tokens(@wfw)

        # Check for duplicate text_hash under different unit_key
        # Load candidates and compute hashes in memory (necessary for hash comparison)
        text_candidates = TextContent
          .where(source_id: @tc.source_id)
          .where.not(id: @tc.id)
          .where("content IS NOT NULL AND content != ''")
          .limit(1000) # Reasonable limit to prevent memory issues
          .to_a

        text_duplicates = text_candidates.select do |other|
          other_hash = GreekNormalizer.hash_text(other.content)
          other_hash == text_hash && other.unit_key != @tc.unit_key
        end

        if text_duplicates.any?
          conflicting_keys = text_duplicates.map(&:unit_key).join(', ')
          hash_prefix = text_hash[0..7]
          return ValidatorResult.fail(
            errors: "Duplicate source_text hash detected. Current unit_key: #{@tc.unit_key}, Conflicting: #{conflicting_keys}",
            flags: ['UNIT_KEY_TEXT_DUPLICATE'],
            meta: {
              current_unit_key: @tc.unit_key,
              conflicting_unit_keys: text_duplicates.map(&:unit_key),
              hash_prefix: hash_prefix
            }
          )
        end

        # Check for duplicate token_hash under different unit_key
        token_candidates = TextContent
          .where(source_id: @tc.source_id)
          .where.not(id: @tc.id)
          .where("word_for_word_translation IS NOT NULL AND word_for_word_translation != '[]'::jsonb")
          .limit(1000) # Reasonable limit
          .to_a

        token_duplicates = token_candidates.select do |other|
          other_wfw = other.word_for_word_array
          next false if other_wfw.empty?

          other_token_hash = GreekNormalizer.hash_tokens(other_wfw)
          other_token_hash == token_hash && other.unit_key != @tc.unit_key
        end

        if token_duplicates.any?
          conflicting_keys = token_duplicates.map(&:unit_key).join(', ')
          hash_prefix = token_hash[0..7]
          return ValidatorResult.fail(
            errors: "Duplicate token hash detected. Current unit_key: #{@tc.unit_key}, Conflicting: #{conflicting_keys}",
            flags: ['UNIT_KEY_TOKEN_DUPLICATE'],
            meta: {
              current_unit_key: @tc.unit_key,
              conflicting_unit_keys: token_duplicates.map(&:unit_key),
              hash_prefix: hash_prefix
            }
          )
        end

        ValidatorResult.ok
      end
    end
  end
end

