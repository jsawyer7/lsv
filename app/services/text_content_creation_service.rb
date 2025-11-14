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
    source = nil
    
    # Strategy 1: Try to find by ID if source_name is numeric
    if @source_name.to_i.to_s == @source_name
      source = Source.unscoped.find_by(id: @source_name.to_i)
    end
    
    # Strategy 2: Exact match by name
    source ||= Source.unscoped.find_by(name: @source_name)
    
    # Strategy 3: Case-insensitive exact match
    source ||= Source.unscoped.where('LOWER(TRIM(name)) = LOWER(TRIM(?))', @source_name).first
    
    # Strategy 4: Try to find by code if source_name looks like a code
    if @source_name.match?(/^[A-Z_]+$/)
      source ||= Source.unscoped.find_by(code: @source_name)
    end
    
    # Strategy 5: Partial match (contains)
    source ||= Source.unscoped.where('name ILIKE ?', "%#{@source_name}%").first
    
    # Strategy 6: Try matching key words (Westcott, Hort, 1881)
    if @source_name.include?('Westcott') || @source_name.include?('Hort') || @source_name.include?('1881')
      source ||= Source.unscoped.where('name ILIKE ? OR name ILIKE ? OR name ILIKE ?', 
                                        '%Westcott%', '%Hort%', '%1881%').first
    end
    
    unless source
      return error_response("Unknown source_name: #{@source_name}. Available sources: #{Source.unscoped.pluck(:name).join(', ')}")
    end

    # Step 2: Resolve current book (use unscoped to avoid default scope issues)
    current_book = nil
    
    # Strategy 1: Try to find by code
    current_book = Book.unscoped.find_by(code: @current_book_code)
    
    # Strategy 2: Try case-insensitive code match
    current_book ||= Book.unscoped.where('LOWER(code) = LOWER(?)', @current_book_code).first
    
    # Strategy 3: Handle common code variations (JHN -> JOH, etc.)
    code_variations = {
      'JHN' => ['JOH', 'JOHN'],
      'JOH' => ['JHN', 'JOHN'],
      'JOHN' => ['JHN', 'JOH']
    }
    if code_variations[@current_book_code]
      code_variations[@current_book_code].each do |variant|
        current_book ||= Book.unscoped.find_by(code: variant)
        break if current_book
      end
    end
    
    # Strategy 4: Try to find by std_name if code doesn't match
    current_book ||= Book.unscoped.where('LOWER(std_name) = LOWER(?)', @current_book_code).first
    
    # Strategy 5: Try partial match on std_name
    current_book ||= Book.unscoped.where('std_name ILIKE ?', "%#{@current_book_code}%").first
    
    unless current_book
      available_books = Book.unscoped.limit(20).pluck(:code, :std_name).map { |c, n| "#{c} (#{n})" }.join(', ')
      return error_response("Unknown book_code: #{@current_book_code}. Available books: #{available_books}")
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
    used_fallback = next_location[:fallback] == true

    result = create_text_content_record(
      source: source,
      book: next_book,
      chapter: next_chapter,
      verse: next_verse,
      used_fallback: used_fallback
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

  def find_next_verse_with_ai(source:, current_book:, current_chapter:, current_verse:, retry_count: 0)
    max_retries = 2
    
    # Get expected verse count for validation
    expected_verses = VerseCountReference.expected_verses(current_book.code, current_chapter)
    next_verse = current_verse + 1
    
    # VALIDATION: Check if next verse is within expected range
    if expected_verses && next_verse <= expected_verses
      # Next verse is within expected range - AI should say YES, but we'll validate
      Rails.logger.info "Verse #{next_verse} is within expected range (#{expected_verses} verses) for #{current_book.code} #{current_chapter}"
    elsif expected_verses && next_verse > expected_verses
      # Next verse is beyond expected range - likely end of chapter
      Rails.logger.info "Verse #{next_verse} is beyond expected range (#{expected_verses} verses) for #{current_book.code} #{current_chapter}"
    end

    # Use AI validator to check if next verse exists
    validator = TextContentAiValidatorService.new(
      source_name: source.name,
      current_book_code: current_book.code,
      current_chapter: current_chapter,
      current_verse: current_verse
    )

    validation_result = validator.validate_structure

    if validation_result[:status] == 'error'
      # If AI validation fails, use fallback logic
      return fallback_to_next_verse(
        source: source,
        current_book: current_book,
        current_chapter: current_chapter,
        current_verse: current_verse,
        expected_verses: expected_verses
      )
    end

    # Check Q2: Has next verse in same chapter?
    if validation_result[:has_next_verse_in_same_chapter]
      return {
        status: 'success',
        book: current_book,
        chapter: current_chapter,
        verse: next_verse
      }
    end

    # RETRY LOGIC: If AI says NO and we haven't retried, try once more
    # Only retry if verse is within expected range (AI might have made a mistake)
    if retry_count < max_retries && expected_verses && next_verse <= expected_verses
      Rails.logger.info "AI said NO to verse #{next_verse} but it's within expected range (#{expected_verses}). Retrying AI validation (attempt #{retry_count + 1}/#{max_retries})"
      sleep(1) # Brief pause before retry
      return find_next_verse_with_ai(
        source: source,
        current_book: current_book,
        current_chapter: current_chapter,
        current_verse: current_verse,
        retry_count: retry_count + 1
      )
    end

    # FALLBACK: If AI says NO but verse is within expected range, try anyway
    # This runs after retries are exhausted
    if expected_verses && next_verse <= expected_verses
      Rails.logger.warn "AI said NO to verse #{next_verse} after #{retry_count} retries, but it's within expected range (#{expected_verses}). Using fallback - will try creating it anyway."
      return {
        status: 'success',
        book: current_book,
        chapter: current_chapter,
        verse: next_verse,
        fallback: true
      }
    end

    # Check if we've reached the expected last verse
    if expected_verses && current_verse >= expected_verses
      # We've reached or passed the expected last verse - move to next chapter
      Rails.logger.info "Reached expected last verse (#{expected_verses}) for #{current_book.code} #{current_chapter}, moving to next chapter"
    end

    # Check Q3: Has first verse in next chapter?
    if validation_result[:has_first_verse_in_next_chapter]
      next_chapter = current_chapter + 1
      next_chapter_expected = VerseCountReference.expected_verses(current_book.code, next_chapter)
      
      # Validate that next chapter exists in our reference
      if next_chapter_expected.nil? && expected_verses
        # We have data for current chapter but not next - might be end of book
        Rails.logger.warn "No verse count data for #{current_book.code} Chapter #{next_chapter}, but AI says it exists"
      end
      
      return {
        status: 'success',
        book: current_book,
        chapter: next_chapter,
        verse: 1
      }
    end

    # Check Q4: Has first verse in next book?
    if validation_result[:has_first_verse_in_next_book] == true
      # For John-only processing, don't move to Acts
      if current_book.code == 'JHN' || current_book.code == 'JOH'
        return { status: 'complete' }
      end

      current_index = BOOK_ORDER.index(current_book.code)
      return { status: 'error', error: 'Current book not in BOOK_ORDER' } unless current_index

      next_index = current_index + 1
      return { status: 'complete' } if next_index >= BOOK_ORDER.length

      next_book_code = BOOK_ORDER[next_index]
      next_book = Book.unscoped.find_by(code: next_book_code)
      next_book ||= Book.unscoped.where('LOWER(code) = LOWER(?)', next_book_code).first
      return { status: 'error', error: "Next book #{next_book_code} not found" } unless next_book

      return {
        status: 'success',
        book: next_book,
        chapter: 1,
        verse: 1
      }
    end

    # Final validation: Check if we should be complete
    if expected_verses && current_verse >= expected_verses
      # Check if there are more chapters in the book
      next_chapter_expected = VerseCountReference.expected_verses(current_book.code, current_chapter + 1)
      if next_chapter_expected
        # Next chapter exists - move to it
        return {
          status: 'success',
          book: current_book,
          chapter: current_chapter + 1,
          verse: 1
        }
      else
        # No more chapters - check if there's a next book
        if current_book.code == 'JHN' || current_book.code == 'JOH'
          return { status: 'complete' }
        end
      end
    end

    # Q5: Complete
    { status: 'complete' }
  end

  def fallback_to_next_verse(source:, current_book:, current_chapter:, current_verse:, expected_verses:)
    next_verse = current_verse + 1
    
    # If we have expected verse count and next verse is within range, try it
    if expected_verses && next_verse <= expected_verses
      Rails.logger.info "Using fallback: Creating verse #{next_verse} (within expected range of #{expected_verses})"
      return {
        status: 'success',
        book: current_book,
        chapter: current_chapter,
        verse: next_verse,
        fallback: true
      }
    end
    
    # If we've reached expected last verse, move to next chapter
    if expected_verses && current_verse >= expected_verses
      next_chapter = current_chapter + 1
      next_chapter_expected = VerseCountReference.expected_verses(current_book.code, next_chapter)
      
      if next_chapter_expected
        Rails.logger.info "Using fallback: Moving to next chapter #{next_chapter} (expected #{next_chapter_expected} verses)"
        return {
          status: 'success',
          book: current_book,
          chapter: next_chapter,
          verse: 1,
          fallback: true
        }
      end
    end
    
    # If we can't determine, return error
    { status: 'error', error: 'Unable to determine next verse location' }
  end

  def create_text_content_record(source:, book:, chapter:, verse:, used_fallback: false)
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
        verse: verse,
        used_fallback: used_fallback
      }.to_json,
      response_payload: {
        status: 'created',
        unit_key: unit_key,
        used_fallback: used_fallback
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

