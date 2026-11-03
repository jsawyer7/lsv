module LsvMcp
  module Tools
    class ListSources < LsvMcp::Tool
      requires_scope 'scripture'
      tool_name 'list_sources'
      description 'List the text sources (editions) in LSV, e.g. GRK_SBLGNT (Greek NT), MT_WLC (Hebrew OT), ' \
                  'LXX_SWETE (Septuagint), with their language and how many verses are loaded. ' \
                  'Use the source code with get_verses, search_verses and find_word_occurrences.'
      input_schema(properties: {}, additionalProperties: false)

      def run
        verse_counts = TextContent.unscoped.group(:source_id).count
        sources = Source.unscoped.includes(:language).order(:code).map do |s|
          {
            code: s.code,
            name: s.name,
            description: s.description,
            language: s.language&.code,
            language_name: s.language&.name,
            verses_loaded: verse_counts.fetch(s.id, 0),
            imported_verbatim_from_source_files: TextContent::AI_LOCKED_SOURCE_CODES.include?(s.code)
          }
        end
        { count: sources.size, sources: sources }
      end
    end
  end
end
