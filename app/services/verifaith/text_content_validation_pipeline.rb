module Verifaith
  class TextContentValidationPipeline
    def initialize(text_content:, source_text:, word_for_word:, lsv_literal_reconstruction:, genre_code:, addressed_party_code:, responsible_party_code:)
      @tc = text_content
      @source = text_content.source
      @sc = SourceClassifier.new(@source)
      @source_text = source_text.to_s
      @wfw = word_for_word || []
      @lsv = lsv_literal_reconstruction.to_s
      @genre_code = genre_code
      @addressed_party_code = addressed_party_code
      @responsible_party_code = responsible_party_code
    end

    def run
      result = ValidatorResult.ok

      # Execution order (fail early and cheaply):
      # 1. normalize_greek (always) - done implicitly in validators via GreekNormalizer
      # 2. UnitIdentityValidator (hard fail early)
      # 3. EditionLockValidator (hard fail early)
      # 4. Canonical fidelity (optional, non-fatal when canonical is missing)
      # 5. Swete contamination checks (fail-fast when contaminated)
      # 6. Word-for-word token presence (edition-aware punctuation)
      # 7. GlossPriorityEnforcer (WFW layer)
      # 8. Ensure LSV is chart-derived (minimal enforcement)
      # 9. SubstantivalParticipleNominalizationValidator
      # 10. PunctuationBoundaryValidator
      # 11. ParticleContextValidator
      # 12. Greek no-smoothing rules
      # 13. Required classification fields

      # 1) Unit Identity / Duplicate Mapping Guard (hard fail early)
      unit_identity_result = Validators::UnitIdentityValidator.new(
        text_content: @tc,
        source_text: @source_text,
        word_for_word: @wfw
      ).validate

      # Fail fast on duplicate detection
      return unit_identity_result unless unit_identity_result.ok?

      result.merge!(unit_identity_result)

      # 2) Edition Lock Validator (hard fail early)
      unit_scope = "#{@tc.unit_group}:#{@tc.unit}"
      edition_lock_result = Validators::EditionLockValidator.new(
        source_code: @sc.code,
        book_code: @tc.book.code,
        unit_scope: unit_scope,
        source_text: @source_text
      ).validate

      # Fail fast on edition contamination
      return edition_lock_result unless edition_lock_result.ok?

      result.merge!(edition_lock_result)

      # 3) Canonical fidelity (optional, non-fatal when canonical is missing)
      canonical = CanonicalTextProvider.new(
        source_code: @sc.code,
        book_code: @tc.book.code,
        chapter: @tc.unit_group,
        verse: @tc.unit
      ).fetch

      result.merge!(
        Validators::CanonicalFidelityValidator.new(
          canonical_text: canonical,
          provided_text: @source_text
        ).validate
      )

      # 4) Swete contamination checks (fail-fast when contaminated)
      if @sc.swete?
        detector = SweteContaminationDetector.new(@sc.code, @tc.book.code, @tc.unit_group, @tc.unit, @source_text)
        begin
          detector.validate!
        rescue SweteContaminationDetector::SweteContaminationError => e
          return ValidatorResult.fail(
            errors: e.message,
            flags: ['SWETE_CONTAMINATION'],
            meta: { type: e.contamination_type, details: e.details }
          )
        end
      end

      # 5) Word-for-word token presence (edition-aware punctuation)
      result.merge!(
        Validators::WordForWordTokenPresenceValidator.new(
          source: @source,
          source_text: @source_text,
          word_for_word: @wfw
        ).validate
      )

      # 6) Gloss Priority Enforcer (WFW layer)
      result.merge!(
        Validators::GlossPriorityEnforcer.new(
          word_for_word: @wfw,
          lsv_literal_reconstruction: @lsv
        ).validate
      )

      # 7) Ensure LSV is chart-derived (minimal enforcement)
      result.merge!(
        Validators::LsvFromChartValidator.new(
          source_text: @source_text,
          word_for_word: @wfw,
          lsv_literal_reconstruction: @lsv
        ).validate
      )

      # 8) Substantival Participle Nominalization Validator
      result.merge!(
        Validators::SubstantivalParticipleNominalizationValidator.new(
          lsv_literal_reconstruction: @lsv
        ).validate
      )

      # 9) Punctuation Boundary Validator
      result.merge!(
        Validators::PunctuationBoundaryValidator.new(
          source_text: @source_text,
          lsv_literal_reconstruction: @lsv
        ).validate
      )

      # 10) Particle Context Validator (δὲ default is NOT "but")
      result.merge!(
        Validators::ParticleContextValidator.new(
          source_text: @source_text,
          lsv_literal_reconstruction: @lsv,
          word_for_word: @wfw
        ).validate
      )

      # 11) Greek no-smoothing rules
      result.merge!(
        Validators::GreekNoSmoothingValidator.new(
          source: @source,
          source_text: @source_text,
          word_for_word: @wfw,
          lsv_literal_reconstruction: @lsv
        ).validate
      )

      # 12) Required classification fields
      result.merge!(
        Validators::ClassificationRequiredValidator.new(
          genre_code: @genre_code,
          addressed_party_code: @addressed_party_code,
          responsible_party_code: @responsible_party_code
        ).validate
      )

      result
    end
  end
end



