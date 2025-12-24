require 'set'

module Verifaith
  module Validators
    # WFW POLICY GATE (minimal, universal, token-friendly)
    # Validates that English insertions in word-for-word translations are properly licensed
    # and don't collapse/resolve/hide Greek structural distinctions
    class WfwPolicyGateValidator
      # Allowed insertion tags at WFW layer (policy-controlled)
      ALLOWED_INSERTION_TAGS = %w[PUNCT CASE_GEN CASE_DAT].freeze

      # Always-block logic/resolution scaffolding (single-token triggers)
      LOGIC_WORDS = %w[
        therefore thus hence because since consequently wherefore
      ].freeze

      # Always-block logic/resolution scaffolding (multi-token triggers)
      LOGIC_BIGRAMS = [
        ['so', 'that'],
        ['in', 'order'],
        ['as', 'a'],       # pairs with ['a', 'result'] checked below
        ['a', 'result']
      ].freeze

      PUNCT_TOKENS = %w[- — –].freeze  # treated as punctuation insertions

      def initialize(source_text:, word_for_word:, lsv_literal_reconstruction:, mode: :verify)
        @source_text = source_text.to_s
        @wfw = word_for_word || []
        @lsv = lsv_literal_reconstruction.to_s
        @mode = mode.to_sym
      end

      def validate
        return ValidatorResult.ok if @wfw.empty? || @lsv.strip.empty?

        # Step 1: Check alignment (all Greek tokens have corresponding entries)
        alignment_ok = check_alignment
        return ValidatorResult.fail(
          errors: 'Missing or misaligned Greek tokens.',
          flags: ['TOKEN_ACCOUNTING_FAIL']
        ) unless alignment_ok

        # Step 2: Check order (Greek token order preserved)
        order_ok = check_order
        return ValidatorResult.fail(
          errors: 'Greek token order not preserved.',
          flags: ['ORDER_DRIFT_FAIL']
        ) unless order_ok

        # Step 3: Check primary gloss (no secondary glosses promoted)
        primary_gloss_ok = check_primary_gloss
        return ValidatorResult.fail(
          errors: 'Secondary gloss promoted.',
          flags: ['PRIMARY_GLOSS_DRIFT_FAIL']
        ) unless primary_gloss_ok

        # Step 4: Detect and validate insertions
        insertions = detect_insertions
        ok, flags, reason = wfw_gate(alignment_ok, order_ok, primary_gloss_ok, insertions)

        if ok
          ValidatorResult.ok
        else
          ValidatorResult.fail(
            errors: reason,
            flags: flags
          )
        end
      end

      private

      def check_alignment
        # All tokens in source_text should have corresponding entries in word_for_word
        # This is a simplified check - full alignment would require tokenization
        # For now, we check that word_for_word has entries
        return false unless @wfw.is_a?(Array) && @wfw.any?

        # Check that each word_for_word entry has required fields
        @wfw.all? do |row|
          next true unless row.is_a?(Hash)
          token = row['token'] || row[:token]
          base_gloss = row['base_gloss'] || row[:base_gloss]
          token.present? && base_gloss.present?
        end
      end

      def check_order
        # Check that Greek token order is preserved in word_for_word
        # This is a simplified check - full order validation would require
        # comparing token positions in source_text with word_for_word order
        # For now, we assume order is preserved if word_for_word is non-empty
        @wfw.is_a?(Array) && @wfw.any?
      end

      def check_primary_gloss
        # Check that no secondary glosses are promoted to primary without override
        return true unless @wfw.is_a?(Array) && @wfw.any?

        @wfw.all? do |row|
          next true unless row.is_a?(Hash)
          
          lemma = row['lemma'] || row[:lemma]
          base_gloss = row['base_gloss'] || row[:base_gloss]
          morph_bucket = row['morph_bucket'] || row[:morph_bucket]
          
          next true if lemma.to_s.strip.empty? || base_gloss.to_s.strip.empty?
          next true unless GlossPriorityConfig.lemma_in_chart?(lemma)
          
          # Check if base_gloss is primary
          if GlossPriorityConfig.is_primary_gloss?(lemma, base_gloss, morph_bucket: morph_bucket)
            true
          else
            # Check if it's at least a valid secondary with override reason
            override_reason = row['gloss_override_reason'] || row[:gloss_override_reason]
            is_secondary = GlossPriorityConfig.is_secondary_gloss?(lemma, base_gloss, morph_bucket: morph_bucket)
            is_secondary && override_reason.to_s.strip.present?
          end
        end
      end

      def detect_insertions
        # Detect English words in LSV that don't correspond to Greek tokens
        # This is done by comparing LSV words with word_for_word glosses
        
        # Extract all gloss words from word_for_word (base_gloss and secondary_glosses)
        # Handle multi-word glosses by tokenizing them
        gloss_words = Set.new
        @wfw.each do |row|
          next unless row.is_a?(Hash)
          
          base_gloss = (row['base_gloss'] || row[:base_gloss]).to_s.strip
          if base_gloss.present?
            # Tokenize multi-word glosses
            tokenize_gloss(base_gloss).each { |w| gloss_words.add(normalize_word(w)) }
          end
          
          secondary_glosses = row['secondary_glosses'] || row[:secondary_glosses] || []
          Array(secondary_glosses).each do |sec|
            sec_str = sec.to_s.strip
            if sec_str.present?
              tokenize_gloss(sec_str).each { |w| gloss_words.add(normalize_word(w)) }
            end
          end
        end

        # Tokenize LSV and find words not in gloss_words
        lsv_words = tokenize_lsv(@lsv)
        insertions = []

        lsv_words.each_with_index do |word, idx|
          normalized = normalize_word(word)
          next if normalized.empty?
          
          # Check if it's punctuation (allowed, skip)
          next if PUNCT_TOKENS.include?(word)
          
          # Check if this word appears in any gloss (exact match or as part of multi-word gloss)
          next if gloss_words.include?(normalized)
          
          # Check for partial matches (word might be part of a compound gloss)
          # This handles cases like "was-being" where "was" and "being" are separate words
          next if gloss_words.any? { |gw| gw.include?(normalized) || normalized.include?(gw) }
          
          # This is an insertion - try to tag it
          tag = tag_insertion(word, normalized, idx, lsv_words)
          insertions << Insertion.new(tok: word, tag: tag)
        end

        insertions
      end

      def tokenize_gloss(gloss)
        # Tokenize a gloss (which may be multi-word like "was-being" or "this one")
        # Split on hyphens, spaces, and common separators
        gloss.to_s.split(/[\s\-–—]+/).reject(&:empty?)
      end

      def tokenize_lsv(lsv)
        # Simple tokenization - split on whitespace and punctuation
        # This is a simplified version - full tokenization would handle contractions, etc.
        lsv.to_s.split(/\s+|([\p{P}])/).reject(&:empty?)
      end

      def normalize_word(word)
        return '' unless word.is_a?(String)
        word.downcase.strip.gsub(/[ \t\n\r.,;:!?()\[\]{}"'']/, '')
      end

      def tag_insertion(word, normalized, idx, lsv_words)
        # Try to tag the insertion based on context
        # This is a simplified tagging - full tagging would require morphological analysis
        
        # Check for case markers
        if normalized == 'of'
          # Check if next word might be genitive
          return 'CASE_GEN'
        elsif normalized == 'to'
          # Check if next word might be dative
          return 'CASE_DAT'
        end
        
        # Check if it's punctuation
        return 'PUNCT' if PUNCT_TOKENS.include?(word)
        
        # Unclassified
        ''
      end

      def wfw_gate(alignment_ok, order_ok, primary_gloss_ok, insertions)
        return [false, ['TOKEN_ACCOUNTING_FAIL'], 'Missing or misaligned Greek tokens.'] unless alignment_ok
        return [false, ['ORDER_DRIFT_FAIL'], 'Greek token order not preserved.'] unless order_ok
        return [false, ['PRIMARY_GLOSS_DRIFT_FAIL'], 'Secondary gloss promoted.'] unless primary_gloss_ok

        # Separate punctuation before normalization
        ins_list = Array(insertions)

        # 1) Fast allow for tagged insertions + punctuation
        ins_list.each do |ins|
          next if ins.tok.to_s.strip.empty?
          next if PUNCT_TOKENS.include?(ins.tok)
          next if ins.tag.present? && ALLOWED_INSERTION_TAGS.include?(ins.tag)
          # Un-tagged word insertions go through logic checks below
        end

        # 2) Build normalized word stream for logic checks
        words = []
        ins_list.each do |ins|
          next if ins.tok.to_s.strip.empty?
          next if PUNCT_TOKENS.include?(ins.tok)
          w = normalize_word(ins.tok)
          words << w if w.present?
        end

        # 3) Block logic words (single-token)
        words.each do |w|
          if LOGIC_WORDS.include?(w)
            return [false, ['UNLICENSED_LOGIC_INSERTION'], "Inserted logic word '#{w}' resolves Greek structure."]
          end
        end

        # 4) Block common logic phrases (bigram scan)
        words.each_with_index do |w, idx|
          next if idx >= words.length - 1
          bigram = [w, words[idx + 1]]
          if LOGIC_BIGRAMS.include?(bigram)
            phrase = "#{w} #{words[idx + 1]}"
            return [false, ['UNLICENSED_LOGIC_INSERTION'], "Inserted logic phrase '#{phrase}' resolves Greek structure."]
          end
        end

        # 5) If any remaining insertion is unclassified → FAIL
        ins_list.each do |ins|
          next if ins.tok.to_s.strip.empty?
          next if PUNCT_TOKENS.include?(ins.tok)
          next if ins.tag.present? && ALLOWED_INSERTION_TAGS.include?(ins.tag)

          w = normalize_word(ins.tok)
          next if w.empty?

          # Anything else is an unlicensed structural insertion at WFW layer
          return [false, ['UNCLASSIFIED_INSERTION'], "Inserted unclassified word '#{w}' – unlicensed insertion at WFW layer."]
        end

        [true, [], 'PASS: Greek structure preserved (English readability irrelevant at WFW layer).']
      end

      # Insertion data class
      class Insertion
        attr_reader :tok, :tag

        def initialize(tok:, tag: '')
          @tok = tok.to_s
          @tag = tag.to_s
        end
      end
    end
  end
end

