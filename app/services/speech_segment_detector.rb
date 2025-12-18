# Service to detect speech segments in biblical text
# Used to identify continuous speech blocks before assigning responsible_party
class SpeechSegmentDetector
  # Divine speech intro patterns
  DIVINE_SPEECH_INTROS = [
    /λέγει κύριος/i,
    /τάδε λέγει κύριος/i,
    /εἶπεν ὁ θεός/i,
    /εἶπεν ὁ κύριος/i,
    /ἐγώ εἰμι κύριος/i,
    /ὁ θεός τῶν πατέρων σου/i
  ].freeze

  # Human speech intro patterns (common names in LXX)
  HUMAN_SPEECH_INTROS = [
    /εἶπεν Δαυίδ/i,
    /εἶπεν Ἰώβ/i,
    /εἶπεν Σολομών/i,
    /εἶπεν Μωυσῆς/i,
    /εἶπεν Ἠσαΐας/i,
    /εἶπεν Ἱερεμίας/i,
    /εἶπεν Ἰεζεκιήλ/i,
    /εἶπεν Δανιήλ/i
  ].freeze

  # Speech continuation markers (indicates speech continues)
  SPEECH_CONTINUATION = [
    /λέγων/i,  # "saying"
    /καὶ εἶπεν/i,  # "and said"
    /καὶ λέγει/i   # "and says"
  ].freeze

  # Narrative break markers (indicates speech has ended)
  NARRATIVE_BREAKS = [
    /καὶ ἐγένετο/i,  # "and it came to pass"
    /καὶ εἶδεν/i,     # "and he saw"
    /καὶ ἐποίησεν/i,  # "and he did"
    /καὶ ἐξῆλθεν/i,   # "and he went out"
    /καὶ ἦλθεν/i      # "and he came"
  ].freeze

  def initialize(source, book, chapter)
    @source = source
    @book = book
    @chapter = chapter
  end

  # Detect speech segments for a chapter
  # Returns: { verse_num => { speaker_type: 'DIVINE'|'HUMAN'|nil, speaker_name: string|nil } }
  def detect_speech_segments
    segments = {}
    current_speaker = nil
    current_speaker_name = nil

    # Get all verses for this chapter
    verses = TextContent.unscoped.where(
      source_id: @source.id,
      book_id: @book.id,
      unit_group: @chapter
    ).order(:unit).to_a

    verses.each do |verse|
      content = verse.content.to_s
      verse_key = verse.unit.to_s

      # Check for new speech intro
      divine_intro = DIVINE_SPEECH_INTROS.find { |pattern| pattern.match?(content) }
      human_intro = HUMAN_SPEECH_INTROS.find { |pattern| pattern.match?(content) }

      if divine_intro
        current_speaker = 'DIVINE'
        current_speaker_name = extract_speaker_name(content, divine_intro) || 'GOD'
        segments[verse_key] = { speaker_type: current_speaker, speaker_name: current_speaker_name }
      elsif human_intro
        current_speaker = 'HUMAN'
        current_speaker_name = extract_speaker_name(content, human_intro)
        segments[verse_key] = { speaker_type: current_speaker, speaker_name: current_speaker_name }
      elsif current_speaker
        # Check if speech continues or breaks
        if speech_continues?(content)
          segments[verse_key] = { speaker_type: current_speaker, speaker_name: current_speaker_name }
        elsif narrative_break?(content)
          current_speaker = nil
          current_speaker_name = nil
          # Verse is not in a speech segment
        else
          # Default: continue current speech if we're in one
          segments[verse_key] = { speaker_type: current_speaker, speaker_name: current_speaker_name }
        end
      end
      # If no current_speaker and no intro, verse is not in a speech segment
    end

    segments
  end

  # Check if a verse is in a speech segment
  def verse_in_speech_segment?(verse_num, segments = nil)
    segments ||= detect_speech_segments
    segment = segments[verse_num.to_s]
    segment && segment[:speaker_type].present?
  end

  # Get speaker info for a verse
  def get_speaker_info(verse_num, segments = nil)
    segments ||= detect_speech_segments
    segments[verse_num.to_s] || {}
  end

  private

  def extract_speaker_name(content, intro_pattern)
    # Try to extract speaker name from intro pattern
    # For divine: return 'GOD'
    # For human: extract name from pattern
    if intro_pattern.source.include?('Δαυίδ')
      'DAVID'
    elsif intro_pattern.source.include?('Ἰώβ')
      'JOB'
    elsif intro_pattern.source.include?('Σολομών')
      'SOLOMON'
    elsif intro_pattern.source.include?('Μωυσῆς')
      'MOSES'
    elsif intro_pattern.source.include?('Ἠσαΐας')
      'ISAIAH'
    elsif intro_pattern.source.include?('Ἱερεμίας')
      'JEREMIAH'
    elsif intro_pattern.source.include?('Ἰεζεκιήλ')
      'EZEKIEL'
    elsif intro_pattern.source.include?('Δανιήλ')
      'DANIEL'
    elsif intro_pattern.source.include?('κύριος') || intro_pattern.source.include?('θεός')
      'GOD'
    else
      nil
    end
  end

  def speech_continues?(content)
    SPEECH_CONTINUATION.any? { |pattern| pattern.match?(content) }
  end

  def narrative_break?(content)
    NARRATIVE_BREAKS.any? { |pattern| pattern.match?(content) }
  end
end

