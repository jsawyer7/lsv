require 'digest'

module Verifaith
  module GreekNormalizer
    # Unicode confusables: Greek letters that look like Latin letters
    # Common ones: Α (Greek Alpha) vs A (Latin), Ο (Greek Omicron) vs O (Latin), etc.
    GREEK_LETTERS = /[Α-Ωα-ωϐ-ϡ]/.freeze
    LATIN_LOOKALIKES = {
      'A' => 'Α', 'B' => 'Β', 'E' => 'Ε', 'H' => 'Η', 'I' => 'Ι', 'K' => 'Κ',
      'M' => 'Μ', 'N' => 'Ν', 'O' => 'Ο', 'P' => 'Ρ', 'T' => 'Τ', 'X' => 'Χ',
      'Y' => 'Υ', 'Z' => 'Ζ',
      'a' => 'α', 'e' => 'ε', 'h' => 'η', 'i' => 'ι', 'o' => 'ο', 'p' => 'ρ',
      't' => 'τ', 'x' => 'χ', 'y' => 'υ', 'v' => 'ν'
    }.freeze

    module_function

    # Normalize Greek text for hashing and comparison
    # - Unicode NFC normalization
    # - Trim
    # - Collapse internal whitespace to single space
    # - Preserve punctuation (Swete accuracy depends on it)
    # Returns: { normalized: String, confusables_detected: Array<String> }
    def normalize_greek(text)
      return { normalized: '', confusables_detected: [] } if text.nil? || text.to_s.strip.empty?

      s = text.to_s
      confusables = detect_confusables(s)

      # Unicode NFC normalization
      s = s.unicode_normalize(:nfc)

      # Trim
      s = s.strip

      # Collapse internal whitespace to single space (preserve punctuation)
      s = s.gsub(/\s+/, ' ')

      { normalized: s, confusables_detected: confusables }
    end

    # Detect mixed-script confusables (Greek letters replaced by Latin lookalikes)
    def detect_confusables(text)
      detected = []
      text.scan(/[A-Za-z]/) do |char|
        # Check if this Latin letter appears in a context where Greek is expected
        # Simple heuristic: if we see mostly Greek letters, flag Latin lookalikes
        char_index = text.index(char)
        next unless char_index

        context_start = [0, char_index - 10].max
        context_end = [text.length - 1, char_index + 10].min
        context = text[context_start..context_end]
        greek_count = context.scan(GREEK_LETTERS).count
        total_letters = context.scan(/[A-Za-zΑ-Ωα-ω]/).count

        if total_letters > 0 && (greek_count.to_f / total_letters) > 0.5
          # Mostly Greek context, but found a Latin letter - potential confusable
          detected << char if LATIN_LOOKALIKES.key?(char)
        end
      end
      detected.uniq
    end

    # Compute SHA256 hash of normalized text
    def hash_text(text)
      normalized = normalize_greek(text)[:normalized]
      Digest::SHA256.hexdigest(normalized)
    end

    # Compute SHA256 hash of token sequence
    def hash_tokens(word_for_word_array)
      tokens = extract_tokens(word_for_word_array)
      token_string = tokens.join('|')
      Digest::SHA256.hexdigest(token_string)
    end

    # Extract tokens from word_for_word array
    def extract_tokens(word_for_word_array)
      return [] unless word_for_word_array.is_a?(Array)

      word_for_word_array.map do |row|
        next nil unless row.is_a?(Hash)
        tok = row['token'] || row[:token]
        tok.to_s.strip
      end.compact.reject(&:empty?)
    end

    private
  end
end

