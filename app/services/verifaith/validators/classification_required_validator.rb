module Verifaith
  module Validators
    class ClassificationRequiredValidator
      GENRES = %w[
        NARRATIVE LAW PROPHECY WISDOM POETRY_SONG PARABLE GOSPEL_TEACHING_SAYING
        EPISTLE_LETTER APOCALYPTIC_VISION GENEALOGY_LIST PRAYER
      ].freeze

      PARTY = %w[
        INDIVIDUAL ISRAEL JUDAH JEWS GENTILES DISCIPLES BELIEVERS ALL_PEOPLE CHURCH NOT_SPECIFIED
      ].freeze

      def initialize(genre_code:, addressed_party_code:, responsible_party_code:)
        @genre = genre_code.to_s
        @addr = addressed_party_code.to_s
        @resp = responsible_party_code.to_s
      end

      def validate
        missing = []

        if @genre.empty? || !GENRES.include?(@genre)
          missing << 'genre_code'
        end

        if @addr.empty? || !PARTY.include?(@addr)
          missing << 'addressed_party_code'
        end

        if @resp.empty? || !PARTY.include?(@resp)
          missing << 'responsible_party_code'
        end

        if missing.any?
          ValidatorResult.fail(
            errors: "Missing/invalid classification fields: #{missing.join(', ')}",
            flags: ['MISSING_REQUIRED_FIELDS'],
            meta: { missing: missing }
          )
        else
          ValidatorResult.ok
        end
      end
    end
  end
end



