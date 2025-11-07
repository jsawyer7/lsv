require 'openai'

class TextContentCreationService
  # Standard New Testament book order
  BOOK_ORDER = [
    "MAT", "MRK", "LUK", "JHN", "ACT", "ROM", "1CO", "2CO", "GAL", "EPH", "PHP", "COL",
    "1TH", "2TH", "1TI", "2TI", "TIT", "PHM", "HEB", "JAS", "1PE", "2PE", "1JN", "2JN",
    "3JN", "JUD", "REV"
  ].freeze

  def initialize(source_name:, current_book_code:, current_chapter:, current_verse:)
    @source_name = source_name
    @current_book_code = current_book_code
    @current_chapter = current_chapter
    @current_verse = current_verse
  end

  def create_next
    # Step 1: Resolve source (use unscoped to avoid default scope issues)
    source = Source.unscoped.find_by(name: @source_name)
    unless source
      # Try case-insensitive search as fallback
      source = Source.unscoped.where('name ILIKE ?', @source_name).first
      unless source
        return error_response("Unknown source_name: #{@source_name}")
      end
    end

    # Step 2: Resolve current book (use unscoped to avoid default scope issues)
    current_book = Book.unscoped.find_by(code: @current_book_code)
    unless current_book
      return error_response("Unknown book_code: #{@current_book_code}")
    end

    # Step 3: Verify current verse exists in text_contents (or create first one)
    # Use unscoped to avoid default scope ordering
    current_text_content = TextContent.unscoped.find_by(
      source_id: source.id,
      book_id: current_book.id,
      unit_group: @current_chapter,
      unit: @current_verse
    )

    # If current doesn't exist, we need to create it first
    unless current_text_content
      # Create the current verse first
      result = create_text_content_record(
        source: source,
        book: current_book,
        chapter: @current_chapter,
        verse: @current_verse
      )
      return result if result[:status] == 'error'
      current_text_content = result[:text_content]
    end

    # Step 4: Find next verse using AI validator
    next_location = find_next_verse_with_ai(
      source: source,
      current_book: current_book,
      current_chapter: @current_chapter,
      current_verse: @current_verse
    )

    if next_location[:status] == 'complete'
      return {
        status: 'complete',
        message: "Last verse of last book reached for source #{@source_name}."
      }
    end

    if next_location[:status] == 'error'
      return error_response(next_location[:error])
    end

    # Step 5: Create the next text_content record
    next_book = next_location[:book]
    next_chapter = next_location[:chapter]
    next_verse = next_location[:verse]

    result = create_text_content_record(
      source: source,
      book: next_book,
      chapter: next_chapter,
      verse: next_verse
    )

    if result[:status] == 'error'
      return error_response(result[:error])
    end

    # Step 6: Return success response
    unit_key = build_unit_key(source.code, next_book.code, next_chapter, next_verse)
    
    {
      status: result[:status] == 'exists' ? 'exists' : 'created',
      created: {
        book_code: next_book.code,
        chapter: next_chapter,
        verse: next_verse,
        unit_key: unit_key
      },
      next_action: {
        instruction: 'create_next_text_content',
        params: {
          source_name: @source_name,
          current: {
            book_code: next_book.code,
            chapter: next_chapter,
            verse: next_verse
          }
        }
      }
    }
  end

  private

  def find_next_verse_with_ai(source:, current_book:, current_chapter:, current_verse:)
    # Use AI validator to check if next verse exists
    validator = TextContentAiValidatorService.new(
      source_name: source.name,
      current_book_code: current_book.code,
      current_chapter: current_chapter,
      current_verse: current_verse
    )

    validation_result = validator.validate_structure

    if validation_result[:status] == 'error'
      return { status: 'error', error: validation_result[:error] }
    end

    # Check Q2: Has next verse in same chapter?
    if validation_result[:has_next_verse_in_same_chapter]
      next_verse = current_verse + 1
      return {
        status: 'success',
        book: current_book,
        chapter: current_chapter,
        verse: next_verse
      }
    end

    # Check Q3: Has first verse in next chapter?
    if validation_result[:has_first_verse_in_next_chapter]
      # Find first verse of next chapter in same book
      # We'll use AI to verify, but for now assume chapter + 1, verse 1
      next_chapter = current_chapter + 1
      return {
        status: 'success',
        book: current_book,
        chapter: next_chapter,
        verse: 1
      }
    end

    # Check Q4: Has first verse in next book?
    # For testing with John only, we'll skip this and mark as complete
    if validation_result[:has_first_verse_in_next_book] == true
      # For now, only process John (JHN) - if we're at John, don't move to Acts
      if current_book.code == 'JHN'
        # For John-only test, mark as complete when we reach the end of John
        return { status: 'complete' }
      end

      current_index = BOOK_ORDER.index(current_book.code)
      return { status: 'error', error: 'Current book not in BOOK_ORDER' } unless current_index

      next_index = current_index + 1
      return { status: 'complete' } if next_index >= BOOK_ORDER.length

      next_book_code = BOOK_ORDER[next_index]
      next_book = Book.unscoped.find_by(code: next_book_code)
      return { status: 'error', error: "Next book #{next_book_code} not found" } unless next_book

      return {
        status: 'success',
        book: next_book,
        chapter: 1,
        verse: 1
      }
    end

    # Q5: Complete
    { status: 'complete' }
  end

  def create_text_content_record(source:, book:, chapter:, verse:)
    # Check if already exists (idempotent) - use unscoped to avoid default scope ordering
    existing = TextContent.unscoped.find_by(
      source_id: source.id,
      book_id: book.id,
      unit_group: chapter,
      unit: verse
    )

    if existing
      return {
        status: 'exists',
        text_content: existing
      }
    end

    # Build unit_key
    unit_key = build_unit_key(source.code, book.code, chapter, verse)

    # Get required associations (use unscoped to avoid default scope issues)
    text_unit_type = source.text_unit_type || TextUnitType.unscoped.find_by(code: 'BIB_VERSE')
    language = source.language

    unless text_unit_type && language
      return {
        status: 'error',
        error: "Missing text_unit_type or language for source #{source.name}"
      }
    end

    # Create new text_content (with empty content for now)
    text_content = TextContent.new(
      source: source,
      book: book,
      text_unit_type: text_unit_type,
      language: language,
      unit_group: chapter,
      unit: verse,
      unit_key: unit_key,
      content: '', # Empty content at this stage
      allow_empty_content: true # Allow empty content for initial creation
    )

    unless text_content.save
      return {
        status: 'error',
        error: "Failed to create text_content: #{text_content.errors.full_messages.join(', ')}"
      }
    end

    # Log the creation
    TextContentApiLog.create!(
      text_content_id: text_content.id,
      source_name: source.name,
      book_code: book.code,
      chapter: chapter,
      verse: verse,
      action: 'create_next',
      request_payload: {
        source_name: source.name,
        book_code: book.code,
        chapter: chapter,
        verse: verse
      }.to_json,
      response_payload: {
        status: 'created',
        unit_key: unit_key
      }.to_json,
      status: 'success'
    )

    {
      status: 'created',
      text_content: text_content
    }
  rescue => e
    {
      status: 'error',
      error: e.message
    }
  end

  def build_unit_key(source_code, book_code, chapter, verse)
    "#{source_code}|#{book_code}|#{chapter}|#{verse}"
  end

  def error_response(message)
    {
      status: 'error',
      error: message
    }
  end
end

