module LsvMcp
  module Tools
    class GetVerses < LsvMcp::Tool
      MAX_VERSES = 200
      MAX_WORD_VERSES = 60

      requires_scope 'scripture'
      tool_name 'get_verses'
      description 'Get the exact text of verses from one source, e.g. source MT_WLC, book GEN, chapter 1, verses 1-5. ' \
                  'Omit verse_from/verse_to for the whole chapter. Lettered verses (e.g. LXX 21:42a) are included in ' \
                  'the range of their number. With include_words, each verse also lists its words with lemma and ' \
                  'morphology (Greek NT and Hebrew OT only; at most 60 verses).'
      input_schema(
        properties: {
          source: { type: 'string', maxLength: 50, description: 'Source code from list_sources, e.g. GRK_SBLGNT.' },
          book: { type: 'string', maxLength: 50, description: 'Book code (GEN, MAT, 1CO) or name (Genesis).' },
          chapter: { type: 'integer', minimum: 0, maximum: 200 },
          verse_from: { type: 'integer', minimum: 0, maximum: 200 },
          verse_to: { type: 'integer', minimum: 0, maximum: 200 },
          include_words: { type: 'boolean', default: false }
        },
        required: %w[source book chapter],
        additionalProperties: false
      )

      def run(source:, book:, chapter:, verse_from: nil, verse_to: nil, include_words: false)
        src = find_source!(source)
        bk = find_book!(book)
        verse_to ||= verse_from
        raise Error, 'verse_to must not be lower than verse_from.' if verse_from && verse_to < verse_from

        verse_number = Arel.sql("NULLIF(substring(text_contents.unit from '^[0-9]+'), '')::int")
        scope = TextContent.unscoped.where(source_id: src.id, book_id: bk.id, unit_group: chapter)
        scope = scope.where("#{verse_number} BETWEEN ? AND ?", verse_from, verse_to) if verse_from
        verses = scope.reorder(verse_number, :unit).limit(MAX_VERSES + 1).to_a
        truncated = verses.size > MAX_VERSES
        verses = verses.first(MAX_VERSES)

        if verses.empty?
          range = verse_from ? ":#{verse_from}#{"-#{verse_to}" if verse_to != verse_from}" : ''
          raise Error, "No verses found for #{src.code} #{bk.code} #{chapter}#{range}."
        end
        if include_words && verses.size > MAX_WORD_VERSES
          raise Error, "include_words is limited to #{MAX_WORD_VERSES} verses; narrow verse_from/verse_to."
        end

        tokens = include_words ? TextContentToken.unscoped.where(text_content_id: verses.map(&:id)).order(:text_content_id, :position).group_by(&:text_content_id) : {}

        {
          source: src.code,
          book: { code: bk.code, name: bk.std_name },
          chapter: chapter,
          count: verses.size,
          truncated: truncated,
          verses: verses.map do |v|
            row = { reference: "#{bk.code} #{v.unit_group}:#{v.unit}", unit_key: v.unit_key, verse: v.unit, text: v.content }
            row[:words] = (tokens[v.id] || []).map { |t| word_json(t) } if include_words
            row
          end
        }
      end

      private

      def word_json(token)
        {
          position: token.position, ref: token.ref, kind: token.kind, surface: token.surface, word: token.word,
          normalized: token.normalized, lemma: token.lemma, pos: token.pos, parsing: token.parsing
        }.compact
      end
    end
  end
end
