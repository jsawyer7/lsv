# Canonical source text - "gold master" text for verification
# This table stores the exact text from vetted source editions (e.g., Swete 1894)
# and is used to verify that pipeline text matches exactly
class CanonicalSourceText < ApplicationRecord
  self.table_name = 'canonical_source_texts'
  self.primary_key = nil  # Using composite key

  # Validations
  validates :source_code, presence: true
  validates :book_code, presence: true
  validates :chapter_number, presence: true
  validates :verse_number, presence: true
  validates :canonical_text, presence: true

  # Find canonical text for a verse
  def self.find_canonical(source_code, book_code, chapter, verse)
    find_by(
      source_code: source_code,
      book_code: book_code,
      chapter_number: chapter,
      verse_number: verse.to_s
    )
  end
end

