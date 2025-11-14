# Reference data for known verse counts in biblical books
# This is used to validate AI responses and provide context to the AI
class VerseCountReference
  # Standard verse counts for the Gospel of John (21 chapters)
  # Source: Standard biblical reference
  JOHN_CHAPTER_VERSES = {
    1 => 51,
    2 => 25,
    3 => 36,
    4 => 54,
    5 => 47,
    6 => 71,
    7 => 53,
    8 => 59,
    9 => 41,
    10 => 42,
    11 => 57,
    12 => 50,
    13 => 38,
    14 => 31,
    15 => 27,
    16 => 33,
    17 => 26,
    18 => 40,
    19 => 42,
    20 => 31,
    21 => 25
  }.freeze

  # Get expected verse count for a chapter
  def self.expected_verses(book_code, chapter)
    case book_code.to_s.upcase
    when 'JHN', 'JOH', 'JOHN'
      JOHN_CHAPTER_VERSES[chapter.to_i]
    else
      nil # Unknown book or chapter
    end
  end

  # Check if a verse number is within expected range
  def self.verse_exists?(book_code, chapter, verse)
    expected = expected_verses(book_code, chapter)
    return true if expected.nil? # If we don't know, assume it might exist
    
    verse.to_i <= expected
  end

  # Get the last verse number for a chapter
  def self.last_verse(book_code, chapter)
    expected_verses(book_code, chapter)
  end

  # Check if we're at or past the last verse
  def self.is_last_verse?(book_code, chapter, verse)
    expected = expected_verses(book_code, chapter)
    return false if expected.nil? # If we don't know, assume it might not be last
    
    verse.to_i >= expected
  end
end

