module LsvMcp
  module Tools
    class FindWordOccurrences < LsvMcp::Tool
      requires_scope 'scripture'
      tool_name 'find_word_occurrences'
      description 'Find where a lemma occurs in the word-by-word data (Greek NT GRK_SBLGNT, Hebrew OT MT_WLC). ' \
                  'Greek lemmas are dictionary forms (e.g. λόγος). Hebrew lemmas are the source file\'s Strong\'s ' \
                  'codes, exactly as written, including prefixes and letters (e.g. "b/7225", "1254 a", "430"). ' \
                  'The match is exact. Returns the total count and the first occurrences.'
      input_schema(
        properties: {
          lemma: { type: 'string', minLength: 1, maxLength: 64 },
          source: { type: 'string', maxLength: 50 },
          limit: { type: 'integer', minimum: 1, maximum: 100, default: 50 }
        },
        required: %w[lemma],
        additionalProperties: false
      )

      def run(lemma:, source: nil, limit: nil)
        scope = TextContentToken.unscoped.joins(text_content: [:source, :book]).where(lemma: lemma.strip)
        scope = scope.where(text_contents: { source_id: find_source!(source).id }) if source.present?

        total = scope.count
        rows = scope.reorder('text_contents.unit_key', 'text_content_tokens.position')
                    .limit(clamp_limit(limit, default: 50, max: 100))
                    .pluck('sources.code', 'books.code', 'text_contents.unit_group', 'text_contents.unit',
                           'text_content_tokens.position', 'text_content_tokens.kind', 'text_content_tokens.surface',
                           'text_content_tokens.lemma', 'text_content_tokens.parsing')
        {
          lemma: lemma,
          total_occurrences: total,
          count: rows.size,
          occurrences: rows.map do |src, bk, ch, vs, pos, kind, surface, lem, parsing|
            { source: src, reference: "#{bk} #{ch}:#{vs}", position: pos, kind: kind, surface: surface, lemma: lem, parsing: parsing }
          end
        }
      end
    end
  end
end
