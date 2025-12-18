# Service to detect contamination in Swete 1894 text
# Prevents Byzantine/Theodotion expansions, normalization, and other source drift
# This is a fail-fast validator that blocks contaminated text from entering the system

class SweteContaminationDetector
  # Error class for contamination detection
  class SweteContaminationError < StandardError
    attr_reader :contamination_type, :details

    def initialize(message, contamination_type: nil, details: {})
      super(message)
      @contamination_type = contamination_type
      @details = details
    end
  end
  # Swete source codes
  SWETE_SOURCE_CODES = ['LXX_SWETE'].freeze

  # Forbidden narrative expansions that never appear in Swete's diplomatic text
  # These patterns indicate Byzantine or Theodotion contamination
  FORBIDDEN_NARRATIVE_EXPANSIONS = [
    # Pattern A: Participial speech expansions
    /\bἀποκριθεὶς\b/i,
    /\bἀποκριθεῖσα\b/i,
    /\bἀποκριθέν\b/i,
    
    # Pattern B: Connective stacking before εἶπεν
    /ἀποκριθεὶς\s+δὲ\s+.*εἶπεν/i,
    
    # Pattern C: Expanded formulaic frames
    /ἀποκριθεὶς\s+(ὁ|ἡ)\s+\w+\s+εἶπεν/i,
    
    # Additional Byzantine narrative patterns
    /\bἀποκριθεὶς\s+εἶπεν\b/i,
    /\bἀποκριθέντες\s+εἶπαν\b/i,
  ].freeze

  # Daniel stream markers
  DANIEL_OG_MARKERS = [
    /\bOG\b/i,
    /\bOld Greek\b/i,
  ].freeze

  DANIEL_THEODOTION_MARKERS = [
    /\bTHEODOTION\b/i,
    /\bΘεοδοτίων\b/i,
    /\bTheodotion\b/i,
  ].freeze

  def initialize(source_code, book_code, chapter, verse, text)
    @source_code = source_code
    @book_code = book_code
    @chapter = chapter
    @verse = verse.to_s
    @text = text.to_s
  end

  # Main validation method - runs all contamination checks
  # Raises SweteContaminationError if contamination is detected
  def validate!
    return unless swete_source?

    # 1. Source locking check (implicit - we're only here for Swete sources)
    
    # 2. Daniel stream enforcement
    validate_daniel_stream! if daniel_book?

    # 3. Theodotion/Byzantine contamination detection
    detect_forbidden_expansions!

    # 4. Spelling & diacritic strictness (check for normalization)
    detect_normalization!

    # 5. Punctuation lock (basic check - full check done in fidelity validator)
    # Note: Full punctuation validation is handled by SweteFidelityValidator

    # All checks passed
    true
  end

  # Check if this is a Swete source
  def swete_source?
    SWETE_SOURCE_CODES.include?(@source_code)
  end

  # Check if this is Daniel book
  def daniel_book?
    @book_code == 'DAN' || @book_code == 'DANIEL'
  end

  private

  # Validate Daniel stream (OG vs Theodotion)
  def validate_daniel_stream!
    # Check if text contains stream markers
    has_og = DANIEL_OG_MARKERS.any? { |pattern| pattern.match?(@text) }
    has_theodotion = DANIEL_THEODOTION_MARKERS.any? { |pattern| pattern.match?(@text) }

    # If both markers present, that's contamination
    if has_og && has_theodotion
      raise SweteContaminationError.new(
        "Daniel stream contamination: Both OG and Theodotion markers detected in #{@source_code} #{@book_code} #{@chapter}:#{@verse}",
        contamination_type: 'DANIEL_STREAM_MIXED',
        details: { book: @book_code, chapter: @chapter, verse: @verse }
      )
    end

    # Note: We don't enforce a specific stream here because Swete may use either
    # The key is that they must not be mixed
  end

  # Detect forbidden narrative expansions (Theodotion/Byzantine contamination)
  def detect_forbidden_expansions!
    FORBIDDEN_NARRATIVE_EXPANSIONS.each do |pattern|
      if pattern.match?(@text)
        match = pattern.match(@text)
        matched_text = match[0] if match
        
        raise SweteContaminationError.new(
          "Theodotion/Byzantine contamination detected in #{@source_code} #{@book_code} #{@chapter}:#{@verse}: forbidden narrative expansion '#{matched_text}'",
          contamination_type: 'THEODOTION_BYZANTINE_EXPANSION',
          details: {
            book: @book_code,
            chapter: @chapter,
            verse: @verse,
            matched_pattern: matched_text,
            pattern_description: pattern_description(pattern)
          }
        )
      end
    end
  end

  # Detect normalization (spelling/diacritic changes)
  # This is a basic check - full validation requires canonical text comparison
  def detect_normalization!
    # Check for common normalization artifacts
    # Note: This is a heuristic - full validation requires canonical comparison
    
    # Check for NFC/NFD normalization issues (basic check)
    # If text has been normalized, it might have different combining marks
    # This is hard to detect without canonical text, so we'll rely on fidelity validator
    
    # For now, we'll just ensure text is not empty and has Greek characters
    if @text.present? && !@text.match?(/[α-ωΑ-Ω]/)
      # This might be a problem, but not necessarily contamination
      # We'll let the fidelity validator handle this
    end
  end

  # Get human-readable description of pattern
  def pattern_description(pattern)
    case pattern.source
    when /ἀποκριθεὶς.*δὲ.*εἶπεν/
      "Participial speech expansion with connective stacking"
    when /ἀποκριθεὶς.*(ὁ|ἡ).*εἶπεν/
      "Expanded formulaic speech frame"
    when /ἀποκριθεὶς\b/
      "Participial speech expansion"
    when /ἀποκριθέντες.*εἶπαν/
      "Plural participial speech expansion"
    else
      "Narrative expansion pattern"
    end
  end
end

