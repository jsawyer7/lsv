module Verifaith
  module Validators
    class CanonicalFidelityValidator
      def initialize(canonical_text:, provided_text:)
        @canon = canonical_text.to_s
        @prov = provided_text.to_s
      end

      def validate
        if @canon.strip.empty?
          return ValidatorResult.warn(
            warnings: 'Canonical text not available; fidelity check skipped',
            flags: ['CANONICAL_SKIPPED'],
            meta: { canonical_fidelity: 'SKIPPED' }
          )
        end

        if @canon == @prov
          ValidatorResult.ok(meta: { canonical_fidelity: 'OK' })
        else
          ValidatorResult.fail(
            errors: 'Canonical fidelity mismatch (provided text differs from canonical)',
            flags: ['CANONICAL_MISMATCH'],
            meta: { canonical_fidelity: 'MISMATCH' }
          )
        end
      end
    end
  end
end



