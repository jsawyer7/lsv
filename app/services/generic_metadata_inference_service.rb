# Generic metadata inference service for biblical text
# Enforces LSV-safe rules for all verses without hard-coding any book/verse
# Based on pure language patterns and explicit text markers
class GenericMetadataInferenceService
  # First person forms (Greek)
  FIRST_PERSON_FORMS = [
    /\bἐγώ\b/i,
    /\bμου\b/i,
    /\bμοι\b/i,
    /\bμε\b/i,
    /\bἡμεῖς\b/i,
    /\bἡμῶν\b/i,
    /\bἡμῖν\b/i,
    /\bἡμᾶς\b/i
  ].freeze

  # Second person forms (Greek)
  SECOND_PERSON_FORMS = [
    /\bσύ\b/i,
    /\bσου\b/i,
    /\bσοι\b/i,
    /\bσε\b/i,
    /\bσὲ\b/i,
    /\bὑμεῖς\b/i,
    /\bὑμῶν\b/i,
    /\bὑμῖν\b/i,
    /\bὑμᾶς\b/i
  ].freeze

  # Second person verb endings (Koine patterns)
  SECOND_PERSON_VERB_ENDINGS = [
    /ῃ\b/i,
    /εις\b/i,
    /ητε\b/i,
    /ετε\b/i,
    /εσθε\b/i,
    /ῃς\b/i
  ].freeze

  # Common verbs of speaking
  SPEECH_VERBS = [
    /\bλέγει\b/i,
    /\bλέγεις\b/i,
    /\bλέγω\b/i,
    /\bλέγετε\b/i,
    /\bεἶπεν\b/i,
    /\bεἶπον\b/i,
    /\bεἴπατε\b/i,
    /\bἔφη\b/i,
    /\bφησί\b/i,
    /\bφασίν\b/i
  ].freeze

  # Divine speaker markers (ONLY valid when coupled with a speech verb)
  DIVINE_SPEAKER_PATTERNS = [
    /\bλέγει κύριος\b/i,
    /\bλέγει ὁ κύριος\b/i,
    /\bλέγει κύριος ὁ θεός\b/i,
    /\bεἶπεν κύριος\b/i,
    /\bεἶπεν ὁ κύριος\b/i,
    /\bτάδε λέγει κύριος\b/i,
    /\bτάδε λέγει κύριος\b/i
  ].freeze

  # Human speaker patterns (can be expanded over time)
  HUMAN_SPEAKER_PATTERNS = [
    /\bεἶπεν\s+.*?δαυ[ίι]δ\b/i,  # εἶπεν Δαυίδ
    /\bεἶπεν\s+.*?μω[υύ]σ[ῆή]ς\b/i,  # εἶπεν Μωυσῆς
    /\bεἶπεν\s+.*?Ἰησοῦς\b/i,  # εἶπεν Ἰησοῦς
    /\bλέγει\s+.*?δαυ[ίι]δ\b/i,
    /\bλέγει\s+.*?μω[υύ]σ[ῆή]ς\b/i,
    /\bλέγει\s+.*?Ἰησοῦς\b/i
  ].freeze

  # Group markers (plural/collective vocatives)
  GROUP_MARKERS = [
    /\bλαοί\b/i,
    /\bἔθνη\b/i,
    /\bυἱοί\b/i,
    /\bτέκνα\b/i,
    /\bἀδελφοί\b/i,
    /\bὑμεῖς\b/i,
    /\bὑμῶν\b/i,
    /\bὑμᾶς\b/i
  ].freeze

  def initialize(greek_text, genre_code: nil, existing_responsible_code: 'NOT_SPECIFIED', existing_addressed_code: 'NOT_SPECIFIED', existing_responsible_custom: nil)
    @greek_text = greek_text.to_s.strip
    @genre_code = genre_code
    @existing_responsible_code = existing_responsible_code
    @existing_addressed_code = existing_addressed_code
    @existing_responsible_custom = existing_responsible_custom
  end

  # Main inference method
  # Returns hash with: responsible_party_code, responsible_party_custom_name, addressed_party_code
  def infer_metadata
    {
      responsible_party_code: infer_responsible_party,
      responsible_party_custom_name: infer_responsible_custom_name,
      addressed_party_code: infer_addressed_party
    }
  end

  private

  # Infer responsible party (speaker)
  def infer_responsible_party
    # Start from explicit formulas only
    explicit_code, explicit_custom = detect_explicit_speaker(@greek_text)

    # If there was already a manually set responsible party AND it conflicts with
    # what the text actually says, the text wins.
    if @existing_responsible_code != 'NOT_SPECIFIED'
      # Only keep existing when the text agrees or is silent.
      # We never override explicit text with theology.
      if explicit_code != 'NOT_SPECIFIED'
        return explicit_code
      else
        # Text has no explicit speaker; safest is NOT_SPECIFIED
        return 'NOT_SPECIFIED'
      end
    else
      return explicit_code
    end
  end

  # Infer responsible party custom name
  def infer_responsible_custom_name
    explicit_code, explicit_custom = detect_explicit_speaker(@greek_text)

    # If we detected an explicit speaker, use the custom name
    if explicit_code != 'NOT_SPECIFIED'
      return explicit_custom
    end

    # If existing was set and text doesn't conflict, keep it
    if @existing_responsible_code != 'NOT_SPECIFIED' && explicit_code == 'NOT_SPECIFIED'
      return @existing_responsible_custom
    end

    nil
  end

  # Infer addressed party (listener)
  def infer_addressed_party
    # Poetry/Wisdom/Narrative all follow the same base logic: only 2nd person / vocatives matter.
    if has_second_person?(@greek_text)
      addressed_type = detect_addressed_group_type(@greek_text)
    else
      addressed_type = 'NOT_SPECIFIED'
    end

    # Respect existing metadata ONLY if it doesn't conflict with the text
    if @existing_addressed_code != 'NOT_SPECIFIED'
      # If the existing says someone is addressed but the text has no 2nd person,
      # LSV prefers NOT_SPECIFIED, because the verse does not say who is addressed.
      if !has_second_person?(@greek_text)
        return 'NOT_SPECIFIED'
      else
        return @existing_addressed_code
      end
    else
      return addressed_type
    end
  end

  # Detect explicit speaker from text patterns
  # Returns: [responsible_party_code, responsible_party_custom_name or nil]
  def detect_explicit_speaker(text)
    lowered = text.downcase

    # Explicit divine speech (only when paired with speech verbs)
    DIVINE_SPEAKER_PATTERNS.each do |pattern|
      if pattern.match?(lowered)
        return ['INDIVIDUAL', 'GOD']
      end
    end

    # Explicit human speaker patterns
    HUMAN_SPEAKER_PATTERNS.each do |pattern|
      if pattern.match?(lowered)
        # Extract name if possible
        name = extract_speaker_name(text, pattern)
        return ['INDIVIDUAL', name]
      end
    end

    # No explicit speaker formula → NOT_SPECIFIED
    ['NOT_SPECIFIED', nil]
  end

  # Extract speaker name from pattern match
  def extract_speaker_name(text, pattern)
    match = pattern.match(text)
    return nil unless match

    # Try to extract Greek name from the match
    matched_text = match[0]
    
    # Common name patterns
    if matched_text.match?(/δαυ[ίι]δ/i)
      'DAVID'
    elsif matched_text.match?(/μω[υύ]σ[ῆή]ς/i)
      'MOSES'
    elsif matched_text.match?(/Ἰησοῦς/i)
      'JESUS'
    elsif matched_text.match?(/Ἰώβ/i)
      'JOB'
    elsif matched_text.match?(/Σολομών/i)
      'SOLOMON'
    elsif matched_text.match?(/Ἠσαΐας/i)
      'ISAIAH'
    elsif matched_text.match?(/Ἱερεμίας/i)
      'JEREMIAH'
    elsif matched_text.match?(/Ἰεζεκιήλ/i)
      'EZEKIEL'
    elsif matched_text.match?(/Δανιήλ/i)
      'DANIEL'
    else
      nil
    end
  end

  # Check if text has first person markers
  def has_first_person?(text)
    FIRST_PERSON_FORMS.any? { |pattern| pattern.match?(text) }
  end

  # Check if text has second person markers
  def has_second_person?(text)
    return true if SECOND_PERSON_FORMS.any? { |pattern| pattern.match?(text) }

    # Check for 2nd person verb endings
    tokens = text.split(/\s+/)
    tokens.each do |token|
      # Strip punctuation crudely
      core = token.gsub(/[·,.;:!?«»"ʼ'']/, '')
      if SECOND_PERSON_VERB_ENDINGS.any? { |pattern| pattern.match?(core) }
        return true
      end
    end

    false
  end

  # Detect addressed group type based on vocatives/plurals
  # Returns: 'INDIVIDUAL', 'GROUP', or 'NOT_SPECIFIED'
  def detect_addressed_group_type(text)
    lowered = text.downcase

    # Common plural/collective vocatives
    if GROUP_MARKERS.any? { |pattern| pattern.match?(lowered) }
      return 'GROUP'
    end

    # If we see clear 2nd person but no group markers → treat as INDIVIDUAL
    if has_second_person?(text)
      return 'INDIVIDUAL'
    end

    'NOT_SPECIFIED'
  end
end

