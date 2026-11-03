module LsvMcp
  module Tools
    class SearchVerses < LsvMcp::Tool
      requires_scope 'scripture'
      tool_name 'search_verses'
      description 'Find verses whose text contains the given words (case-insensitive substring match on the original ' \
                  'text). Hebrew text includes vowel points and accents, so an unpointed Hebrew query will usually not ' \
                  'match; use find_word_occurrences with a lemma instead. Optionally restrict to a source and/or book.'
      input_schema(
        properties: {
          text: { type: 'string', minLength: 2, maxLength: 200 },
          source: { type: 'string', maxLength: 50 },
          book: { type: 'string', maxLength: 50 },
          limit: { type: 'integer', minimum: 1, maximum: 50, default: 20 }
        },
        required: %w[text],
        additionalProperties: false
      )

      def run(text:, source: nil, book: nil, limit: nil)
        scope = TextContent.unscoped.where('text_contents.content ILIKE ?', like_pattern(text))
        scope = scope.where(source_id: find_source!(source).id) if source.present?
        scope = scope.where(book_id: find_book!(book).id) if book.present?

        verses = scope.includes(:source, :book).reorder(:unit_key).limit(clamp_limit(limit, default: 20, max: 50)).to_a
        {
          query: text,
          count: verses.size,
          verses: verses.map do |v|
            { source: v.source.code, reference: verse_reference(v), unit_key: v.unit_key, text: v.content }
          end
        }
      end
    end
  end
end
