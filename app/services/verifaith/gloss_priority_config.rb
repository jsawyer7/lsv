require 'json'

module Verifaith
  module GlossPriorityConfig
    CONFIG_DIR = Rails.root.join('config', 'verifaith').freeze

    module_function

    # Load lemma_gloss_chart.json
    # Format: { "lemma": { "primary": "gloss", "secondary": ["gloss1", "gloss2"] } }
    # Or: { "lemma": { "morph_bucket": { "primary": "gloss", "secondary": [...] } } }
    def lemma_gloss_chart
      @lemma_gloss_chart ||= load_json('lemma_gloss_chart.json') || {}
    end

    # Get primary gloss for a lemma (optionally with morph bucket)
    def primary_gloss(lemma, morph_bucket: nil)
      entry = lemma_gloss_chart[lemma]
      return nil unless entry

      if morph_bucket && entry.is_a?(Hash) && entry[morph_bucket]
        entry[morph_bucket]['primary'] || entry[morph_bucket][:primary]
      elsif entry.is_a?(Hash)
        entry['primary'] || entry[:primary]
      else
        nil
      end
    end

    # Get secondary glosses for a lemma (optionally with morph bucket)
    def secondary_glosses(lemma, morph_bucket: nil)
      entry = lemma_gloss_chart[lemma]
      return [] unless entry

      if morph_bucket && entry.is_a?(Hash) && entry[morph_bucket]
        (entry[morph_bucket]['secondary'] || entry[morph_bucket][:secondary] || []).flatten
      elsif entry.is_a?(Hash)
        (entry['secondary'] || entry[:secondary] || []).flatten
      else
        []
      end
    end

    # Check if a gloss is primary for a lemma
    def is_primary_gloss?(lemma, gloss, morph_bucket: nil)
      primary = primary_gloss(lemma, morph_bucket: morph_bucket)
      return false unless primary

      # Normalize for comparison (case-insensitive, trimmed)
      primary_normalized = primary.to_s.strip.downcase
      gloss_normalized = gloss.to_s.strip.downcase

      primary_normalized == gloss_normalized
    end

    # Check if a gloss is secondary for a lemma
    def is_secondary_gloss?(lemma, gloss, morph_bucket: nil)
      secondaries = secondary_glosses(lemma, morph_bucket: morph_bucket)
      return false if secondaries.empty?

      gloss_normalized = gloss.to_s.strip.downcase
      secondaries.any? { |sec| sec.to_s.strip.downcase == gloss_normalized }
    end

    # Check if a lemma exists in the chart
    def lemma_in_chart?(lemma)
      lemma_gloss_chart.key?(lemma)
    end

    # Load JSON config file (module function)
    def load_json(filename)
      path = CONFIG_DIR.join(filename)
      return {} unless File.exist?(path)

      JSON.parse(File.read(path))
    rescue JSON::ParserError, Errno::ENOENT => e
      Rails.logger.warn "Failed to load #{filename}: #{e.message}"
      {}
    end

    module_function :load_json
  end
end

