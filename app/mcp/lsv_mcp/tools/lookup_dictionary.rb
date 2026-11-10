module LsvMcp
  module Tools
    class LookupDictionary < LsvMcp::Tool
      # A safety ceiling, not a working limit: the largest entry has 157 senses.
      MAX_SENSES = 200
      SENSES_SQL = Arel.sql(<<~SQL.squish).freeze
        (SELECT jsonb_agg(jsonb_build_object('glosses', COALESCE(s.value->'glosses', s.value->'raw_glosses'),
                                             'tags', s.value->'tags') ORDER BY s.n)
         FROM jsonb_array_elements(CASE jsonb_typeof(dictionary_entries.payload->'senses')
                                     WHEN 'array' THEN dictionary_entries.payload->'senses' ELSE '[]'::jsonb END)
              WITH ORDINALITY AS s(value, n)
         WHERE s.n <= #{MAX_SENSES}) AS senses
      SQL
      SENSES_TOTAL_SQL = Arel.sql(<<~SQL.squish).freeze
        (CASE jsonb_typeof(dictionary_entries.payload->'senses')
           WHEN 'array' THEN jsonb_array_length(dictionary_entries.payload->'senses') ELSE 0 END) AS senses_total
      SQL

      requires_scope 'dictionary'
      tool_name 'lookup_dictionary'
      description 'Look up a word in the LSV dictionary (English Wiktionary data, 1.4M entries). ' \
                  'Returns part of speech, etymology and the glosses of each sense. ' \
                  'match "exact" (default) is case-insensitive; "prefix" finds words starting with the text.'
      input_schema(
        properties: {
          word: { type: 'string', minLength: 1, maxLength: 100 },
          match: { type: 'string', enum: %w[exact prefix], default: 'exact' },
          pos: { type: 'string', enum: DictionaryEntry::POS_OPTIONS, description: 'Optional part of speech filter.' },
          limit: { type: 'integer', minimum: 1, maximum: 20, default: 10 }
        },
        required: %w[word],
        additionalProperties: false
      )

      def run(word:, match: 'exact', pos: nil, limit: nil)
        text = word.strip
        scope = if match == 'prefix'
                  DictionaryEntry.word_start(text)
                else
                  DictionaryEntry.where('lower(dictionary_entries.word) LIKE lower(?)', ActiveRecord::Base.sanitize_sql_like(text))
                end
        scope = scope.where(pos: pos) if pos.present?

        # payload can be several MB (translations, forms); pull out only the sense glosses in SQL.
        entries = scope.select(:id, :word, :lang, :pos, :etymology_number, :etymology_text, SENSES_SQL, SENSES_TOTAL_SQL)
                       .reorder(:word, :id).limit(clamp_limit(limit, default: 10, max: 20)).to_a
        {
          query: text,
          match: match,
          count: entries.size,
          entries: entries.map { |e| entry_json(e) }
        }
      end

      private

      def entry_json(entry)
        senses = entry.senses.is_a?(String) ? JSON.parse(entry.senses) : Array(entry.senses)
        {
          id: entry.id,
          word: entry.word,
          language: entry.lang,
          pos: entry.pos,
          etymology_number: entry.etymology_number,
          etymology: clip(entry.etymology_text, 1_500),
          senses_total: entry.senses_total.to_i,
          senses: senses.map do |s|
            { glosses: Array(s['glosses']).map { |g| clip(g.to_s, 500) }, tags: s['tags'] }.compact
          end
        }
      end
    end
  end
end
