module Verifaith
  class CanonicalTextProvider
    def initialize(source_code:, book_code:, chapter:, verse:)
      @source_code = source_code
      @book_code = book_code
      @chapter = chapter
      @verse = verse
    end

    # Return canonical exact text if available, else nil.
    # For now, we treat canonical as optional and may not have data for most verses.
    def fetch
      return nil unless defined?(CanonicalSourceText)

      canonical = CanonicalSourceText.find_canonical(
        @source_code,
        @book_code,
        @chapter,
        @verse
      )

      canonical&.canonical_text
    rescue StandardError
      # If canonical lookup fails for any reason, treat as unavailable.
      nil
    end
  end
end



