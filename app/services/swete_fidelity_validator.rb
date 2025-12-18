# Service to verify Swete 1894 text fidelity against canonical source
# This ensures pipeline text exactly matches what Swete printed

class SweteFidelityError < StandardError
end

class SweteFidelityValidator
  # Only enforce for Swete source(s)
  SWETE_SOURCE_CODES = ['LXX_SWETE'].freeze

  def initialize(source_code, book_code, chapter, verse)
    @source_code = source_code
    @book_code = book_code
    @chapter = chapter
    @verse = verse.to_s  # Support sub-verses like "17a"
  end

  # Normalize text for safe comparison
  # Only normalizes non-semantic noise, not actual letters or punctuation
  def self.normalize_for_compare(text)
    return "" if text.nil? || text.empty?

    # Unicode NFC normalization (combining marks)
    # Rails/ActiveSupport provides unicode_normalize method
    normalized = text.unicode_normalize(:nfc)

    # Strip leading/trailing whitespace
    normalized = normalized.strip

    # Collapse multiple spaces/tabs/newlines to single space
    normalized = normalized.gsub(/\s+/, ' ')

    normalized
  end

  # Fetch canonical Swete text for the given verse
  # Returns nil if canonical doesn't exist (doesn't raise error)
  def fetch_canonical_text
    canonical = CanonicalSourceText.find_canonical(
      @source_code,
      @book_code,
      @chapter,
      @verse
    )

    return nil unless canonical

    canonical.canonical_text
  end

  # Verify that pipeline text exactly matches canonical Swete text
  # Raises SweteFidelityError if it does not
  # Returns pipeline_text unchanged if canonical doesn't exist (skip check)
  # 
  # This method performs comprehensive validation:
  # 1. Contamination detection (Byzantine/Theodotion expansions)
  # 2. Canonical text fidelity check
  # 3. Punctuation and character-level validation
  def verify(pipeline_text)
    # Only enforce for Swete sources
    unless SWETE_SOURCE_CODES.include?(@source_code)
      return pipeline_text  # no-op for other sources
    end

    # STEP 1: Contamination detection (fail-fast)
    # This catches Byzantine/Theodotion expansions BEFORE canonical comparison
    # This is the critical layer that prevents contaminated text from entering the system
    begin
      detector = SweteContaminationDetector.new(
        @source_code,
        @book_code,
        @chapter,
        @verse,
        pipeline_text
      )
      detector.validate!
    rescue SweteContaminationDetector::SweteContaminationError => e
      error_msg = <<~ERROR
        Swete contamination detected at #{@source_code} #{@book_code} #{@chapter}:#{@verse}
        
        Contamination Type: #{e.contamination_type}
        Details: #{e.details.inspect}
        
        Pipeline text (contaminated):
        #{pipeline_text}
        
        #{e.message}
        
        This text contains Byzantine or Theodotion expansions that do not appear in Swete's diplomatic text.
        The text must be rejected and re-ingested from the correct Swete source.
      ERROR

      Rails.logger.error error_msg
      raise SweteFidelityError.new(
        error_msg,
        error_type: e.contamination_type || 'CONTAMINATION',
        details: e.details
      )
    end

    # STEP 2: Canonical text fidelity check
    canonical_text = fetch_canonical_text
    
    # If canonical doesn't exist, skip verification (don't raise error)
    # But contamination check still runs above
    return pipeline_text unless canonical_text

    norm_pipeline = self.class.normalize_for_compare(pipeline_text)
    norm_canonical = self.class.normalize_for_compare(canonical_text)

    if norm_pipeline != norm_canonical
      # Log detailed diff for debugging
      diff = compute_diff(norm_pipeline, norm_canonical)
      
      error_msg = <<~ERROR
        Swete 1894 fidelity mismatch at #{@source_code} #{@book_code} #{@chapter}:#{@verse}
        
        Pipeline text:
        #{norm_pipeline}
        
        Canonical text:
        #{norm_canonical}
        
        Diff:
        #{diff}
      ERROR

      Rails.logger.error error_msg
      raise SweteFidelityError.new(
        error_msg,
        error_type: 'FIDELITY_MISMATCH',
        details: {
          book: @book_code,
          chapter: @chapter,
          verse: @verse,
          pipeline_length: norm_pipeline.length,
          canonical_length: norm_canonical.length
        }
      )
    end

    pipeline_text  # Return unchanged, just verified
  end

  # Check if canonical text exists for this verse
  def canonical_exists?
    CanonicalSourceText.exists?(
      source_code: @source_code,
      book_code: @book_code,
      chapter_number: @chapter,
      verse_number: @verse
    )
  end

  private

  def compute_diff(pipeline, canonical)
    # Simple character-by-character diff
    pipeline_chars = pipeline.chars
    canonical_chars = canonical.chars
    
    max_len = [pipeline_chars.length, canonical_chars.length].max
    diffs = []
    
    (0...max_len).each do |i|
      p_char = pipeline_chars[i] || '[MISSING]'
      c_char = canonical_chars[i] || '[MISSING]'
      
      if p_char != c_char
        diffs << "Position #{i}: pipeline='#{p_char}' canonical='#{c_char}'"
      end
    end
    
    if diffs.empty?
      "Texts differ in length: pipeline=#{pipeline.length}, canonical=#{canonical.length}"
    else
      diffs.first(10).join("\n")  # Show first 10 differences
    end
  end
end

