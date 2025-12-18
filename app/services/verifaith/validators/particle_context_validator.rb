module Verifaith
  module Validators
    class ParticleContextValidator
      NEAR_WINDOW_TOKENS = 12

      # Contrast signals that allow "but" for δὲ
      CONTRAST_SIGNALS = [
        # μέν...δέ pairing
        { pattern: /\bμέν\b.*\bδέ\b/i, window: NEAR_WINDOW_TOKENS },
        # Explicit adversative
        { pattern: /\bἀλλά\b/i, window: NEAR_WINDOW_TOKENS },
        # Negation contrast patterns
        { pattern: /\bοὐ\b.*\bδέ\b/i, window: NEAR_WINDOW_TOKENS },
        { pattern: /\bμή\b.*\bδέ\b/i, window: NEAR_WINDOW_TOKENS }
      ].freeze

      def initialize(source_text:, lsv_literal_reconstruction:, word_for_word:)
        @source_text = source_text.to_s
        @lsv = lsv_literal_reconstruction.to_s
        @wfw = word_for_word || []
      end

      def validate
        return ValidatorResult.ok if @source_text.strip.empty? || @lsv.strip.empty?

        # Find all instances of δὲ in source text
        delta_positions = find_delta_positions(@source_text)

        return ValidatorResult.ok if delta_positions.empty?

        # Check each δὲ instance
        violations = []
        delta_positions.each do |pos|
          # Extract context window (±12 tokens)
          context = extract_context_window(@source_text, pos, NEAR_WINDOW_TOKENS)

          # Check if contrast signal exists in context
          has_contrast_signal = CONTRAST_SIGNALS.any? do |signal|
            context.match?(signal[:pattern])
          end

          # Find corresponding "but" in LSV (approximate position)
          # This is a heuristic - we look for "but" near where δὲ appears
          lsv_context = extract_lsv_context(@lsv, pos, @source_text.length, NEAR_WINDOW_TOKENS)
          has_but = lsv_context.match?(/\bbut\b/i)

          # If "but" appears without contrast signal, it's a violation
          if has_but && !has_contrast_signal
            violations << {
              position: pos,
              context: context[0..50],
              lsv_context: lsv_context[0..50]
            }
          end
        end

        if violations.any?
          return ValidatorResult.fail(
            errors: "Particle δὲ rendered as 'but' without contrast evidence (#{violations.count} instance(s))",
            flags: ['PARTICLE_ADVERSATIVE_DRIFT'],
            meta: {
              violations: violations,
              default_mapping: 'δὲ → and or now (not "but" without contrast)'
            }
          )
        end

        ValidatorResult.ok
      end

      private

      def find_delta_positions(text)
        positions = []
        text.scan(/\bδέ\b/) do |match|
          positions << Regexp.last_match.offset(0)[0]
        end
        positions
      end

      def extract_context_window(text, position, window_size)
        start_pos = [0, position - (window_size * 10)].max # Rough estimate: 10 chars per token
        end_pos = [text.length, position + (window_size * 10)].min
        text[start_pos..end_pos]
      end

      def extract_lsv_context(lsv, source_pos, source_length, window_size)
        # Map source position to approximate LSV position (proportional)
        lsv_pos = (source_pos.to_f / source_length * lsv.length).to_i
        start_pos = [0, lsv_pos - (window_size * 10)].max
        end_pos = [lsv.length, lsv_pos + (window_size * 10)].min
        lsv[start_pos..end_pos]
      end
    end
  end
end

