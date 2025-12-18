module Verifaith
  module Validators
    class EditionLockValidator
      def initialize(source_code:, book_code:, unit_scope:, source_text:)
        @source_code = source_code
        @book_code = book_code
        @unit_scope = unit_scope # e.g., "1:1" for chapter:verse
        @source_text = source_text.to_s
      end

      def validate
        # Determine expected tradition code
        expected_tradition = EditionLockConfig.expected_tradition_code(@source_code, @book_code)

        # If no tradition mapping exists, skip validation (not all sources need this)
        return ValidatorResult.ok if expected_tradition.nil?

        # Check for denylist markers (non-expected traditions)
        denylist = EditionLockConfig.denylist_markers(@source_code, expected_tradition)

        denylist.each do |marker|
          # Marker can be a string (exact match) or regex pattern
          pattern = if marker.is_a?(String)
                      Regexp.new(Regexp.escape(marker), Regexp::IGNORECASE)
                    elsif marker.is_a?(Hash) && marker['regex']
                      Regexp.new(marker['regex'], marker['flags'] || 0)
                    else
                      Regexp.new(Regexp.escape(marker.to_s), Regexp::IGNORECASE)
                    end

          if @source_text.match?(pattern)
            return ValidatorResult.fail(
              errors: "Edition contamination detected: non-expected tradition marker '#{marker}' found in #{@source_code} #{@book_code}",
              flags: ['EDITION_CONTAMINATION_SUSPECTED'],
              meta: {
                source_code: @source_code,
                book_code: @book_code,
                expected_tradition: expected_tradition,
                detected_marker: marker
              }
            )
          end
        end

        # Check for overflow beyond allowed end markers
        allowed_ends = EditionLockConfig.allowed_end_marker_sequences(@source_code, @book_code, @unit_scope)

        if allowed_ends.any?
          # Check if text contains tokens beyond any allowed end sequence
          allowed_ends.each do |end_sequence|
            # end_sequence is an array of tokens that should be the end
            # If we find tokens after this sequence, it's an overflow
            end_pattern = end_sequence.join('\s+')
            end_regex = Regexp.new(end_pattern, Regexp::IGNORECASE)

            if @source_text.match?(end_regex)
              # Found the end marker, check if there's content after it
              match = @source_text.match(end_regex)
              if match && match.end(0) < @source_text.length
                remaining = @source_text[match.end(0)..-1].strip
                # If remaining content is substantial (not just punctuation/whitespace), it's overflow
                if remaining.length > 5 && remaining.match?(/[Α-Ωα-ω]/)
                  return ValidatorResult.fail(
                    errors: "Edition overflow detected: content beyond allowed end marker in #{@source_code} #{@book_code} #{@unit_scope}",
                    flags: ['EDITION_OVERFLOW_BEYOND_ALLOWED_END'],
                    meta: {
                      source_code: @source_code,
                      book_code: @book_code,
                      unit_scope: @unit_scope,
                      allowed_end_sequence: end_sequence,
                      overflow_text: remaining[0..50] # First 50 chars
                    }
                  )
                end
              end
            end
          end
        end

        ValidatorResult.ok
      end
    end
  end
end

