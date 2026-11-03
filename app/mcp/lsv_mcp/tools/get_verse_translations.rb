module LsvMcp
  module Tools
    class GetVerseTranslations < LsvMcp::Tool
      requires_scope 'translations'
      tool_name 'get_verse_translations'
      description 'Get the translations LSV holds for one verse: the latest translation per target language and ' \
                  'LSV\'s literal reconstruction. These are AI-generated, unlike the original verse text from get_verses.'
      input_schema(
        properties: {
          source: { type: 'string', maxLength: 50 },
          book: { type: 'string', maxLength: 50 },
          chapter: { type: 'integer', minimum: 0, maximum: 200 },
          verse: { type: 'string', maxLength: 10, description: 'Verse number, e.g. "16" or a lettered verse like "42a".' }
        },
        required: %w[source book chapter verse],
        additionalProperties: false
      )

      def run(source:, book:, chapter:, verse:)
        src = find_source!(source)
        bk = find_book!(book)
        text_content = TextContent.unscoped.find_by(source_id: src.id, book_id: bk.id, unit_group: chapter, unit: verse.strip)
        raise Error, "No verse #{src.code} #{bk.code} #{chapter}:#{verse}." unless text_content

        translations = TextTranslation.unscoped.latest.where(text_content_id: text_content.id)
                                      .includes(:language_target).order(:language_target_id).to_a
        {
          source: src.code,
          reference: "#{bk.code} #{chapter}:#{text_content.unit}",
          text: text_content.content,
          lsv_literal_reconstruction: text_content.lsv_literal_reconstruction,
          word_for_word: text_content.word_for_word_array.presence,
          count: translations.size,
          translations: translations.map do |t|
            {
              language: t.language_target&.code,
              language_name: t.language_target&.name,
              translation: t.ai_translation,
              explanation: clip(t.ai_explanation),
              summary_and_differences: clip(t.summary_and_differences),
              model: t.ai_model_name,
              confidence: t.ai_confidence_score&.to_f,
              revision: t.revision_number,
              confirmed_at: t.confirmed_at&.iso8601,
              notes: t.notes
            }
          end
        }
      end
    end
  end
end
