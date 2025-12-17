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

      # 1) Canonical fidelity (optional, non-fatal when canonical is missing)
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

      # 2) Swete contamination checks (fail-fast when contaminated)
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

      # 3) Word-for-word token presence (edition-aware punctuation)
      result.merge!(
        Validators::WordForWordTokenPresenceValidator.new(
          source: @source,
          source_text: @source_text,
          word_for_word: @wfw
        ).validate
      )

      # 4) Ensure LSV is chart-derived (minimal enforcement)
      result.merge!(
        Validators::LsvFromChartValidator.new(
          source_text: @source_text,
          word_for_word: @wfw,
          lsv_literal_reconstruction: @lsv
        ).validate
      )

      # 5) Greek no-smoothing rules
      result.merge!(
        Validators::GreekNoSmoothingValidator.new(
          source: @source,
          source_text: @source_text,
          word_for_word: @wfw,
          lsv_literal_reconstruction: @lsv
        ).validate
      )

      # 6) Required classification fields
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



