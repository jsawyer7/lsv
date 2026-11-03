module LsvMcp
  # Builds the MCP server for one request, exposing only the tools whose data
  # group (scope) the GrokBotConnection is allowed to read.
  module Server
    TOOLS = [
      Tools::ListSources, Tools::ListBooks, Tools::GetVerses, Tools::SearchVerses, Tools::FindWordOccurrences,
      Tools::LookupDictionary, Tools::LookupName,
      Tools::SearchClaims, Tools::GetClaim, Tools::GetChallenge,
      Tools::GetVerseTranslations
    ].freeze

    INSTRUCTIONS = <<~TEXT.freeze
      Read-only access to LSV (Literal Scripture Verification) data. Nothing you call here changes LSV.
      Verse references use a source code (list_sources), a book code (list_books), a chapter and a verse,
      e.g. get_verses(source: "MT_WLC", book: "GEN", chapter: 1, verse_from: 1).
      Verse text is returned exactly as stored; GRK_SBLGNT and MT_WLC were imported verbatim from their source files
      and are not AI-generated. Quote verse text exactly as returned. Translations and reasonings are AI-generated.
    TEXT

    module_function

    def tools_for(connection)
      TOOLS.select { |tool| connection.scope?(tool.scope) }
    end

    def build(connection:, remote_ip:)
      MCP::Server.new(
        name: 'lsv',
        title: 'LSV',
        version: '1.0.0',
        instructions: INSTRUCTIONS,
        tools: tools_for(connection),
        server_context: { connection: connection, remote_ip: remote_ip }
      )
    end
  end
end
