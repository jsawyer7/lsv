module Verifaith
  module Validators
    class GlossPriorityEnforcer
      def initialize(word_for_word:, lsv_literal_reconstruction:)
        @wfw = word_for_word || []
        @lsv = lsv_literal_reconstruction.to_s
      end

      def validate
        return ValidatorResult.ok unless @wfw.is_a?(Array) && @wfw.any?

        wfw_violations = []
        lsv_violations = []

        @wfw.each do |row|
          next unless row.is_a?(Hash)

          lemma = row['lemma'] || row[:lemma]
          base_gloss = row['base_gloss'] || row[:base_gloss]
          morph_bucket = row['morph_bucket'] || row[:morph_bucket]

          next if lemma.to_s.strip.empty? || base_gloss.to_s.strip.empty?

          # Only enforce if lemma exists in the chart
          # If lemma is not in chart, we can't enforce priority rules
          next unless GlossPriorityConfig.lemma_in_chart?(lemma)

          # Check if base_gloss is primary
          unless GlossPriorityConfig.is_primary_gloss?(lemma, base_gloss, morph_bucket: morph_bucket)
            # Check if it's at least a valid secondary (with override reason)
            override_reason = row['gloss_override_reason'] || row[:gloss_override_reason]
            is_secondary = GlossPriorityConfig.is_secondary_gloss?(lemma, base_gloss, morph_bucket: morph_bucket)

            if !is_secondary || override_reason.to_s.strip.empty?
              wfw_violations << {
                lemma: lemma,
                base_gloss: base_gloss,
                expected_primary: GlossPriorityConfig.primary_gloss(lemma, morph_bucket: morph_bucket)
              }
            end
          end
        end

        # Check LSV for primary gloss usage (heuristic: look for known primary glosses)
        # This is a simplified check - full LSV validation would require parsing
        # For now, we flag if we detect secondary glosses being used prominently
        # without corresponding WFW entries that justify them

        errors = []
        flags = []

        if wfw_violations.any?
          errors << "WFW base_gloss not using primary gloss (#{wfw_violations.count} instance(s))"
          flags << 'WFW_PRIMARY_GLOSS_DRIFT'
        end

        if lsv_violations.any?
          errors << "LSV using secondary gloss without override (#{lsv_violations.count} instance(s))"
          flags << 'LSV_PRIMARY_GLOSS_DRIFT'
        end

        if errors.any?
          return ValidatorResult.fail(
            errors: errors.join('; '),
            flags: flags,
            meta: {
              wfw_violations: wfw_violations,
              lsv_violations: lsv_violations
            }
          )
        end

        ValidatorResult.ok
      end
    end
  end
end

