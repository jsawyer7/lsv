require 'json'

module Verifaith
  module EditionLockConfig
    CONFIG_DIR = Rails.root.join('config', 'verifaith').freeze

    module_function

    # Load source_tradition_map.json
    # Format: { "source_code": { "book_code": "tradition_code" } }
    def source_tradition_map
      @source_tradition_map ||= load_json('source_tradition_map.json') || {}
    end

    # Load tradition_marker_denylists.json
    # Format: { "source_code": { "tradition_code": ["marker_pattern", ...] } }
    def tradition_marker_denylists
      @tradition_marker_denylists ||= load_json('tradition_marker_denylists.json') || {}
    end

    # Load allowed_end_markers.json
    # Format: { "source_code": { "book_code": { "unit_scope": ["allowed_end_token_sequence"] } } }
    def allowed_end_markers
      @allowed_end_markers ||= load_json('allowed_end_markers.json') || {}
    end

    # Get expected tradition code for a source+book
    def expected_tradition_code(source_code, book_code)
      source_tradition_map.dig(source_code, book_code)
    end

    # Get denylist markers for a source+tradition
    def denylist_markers(source_code, tradition_code)
      tradition_marker_denylists.dig(source_code, tradition_code) || []
    end

    # Get allowed end markers for a source+book+unit_scope
    def allowed_end_marker_sequences(source_code, book_code, unit_scope)
      allowed_end_markers.dig(source_code, book_code, unit_scope) || []
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

