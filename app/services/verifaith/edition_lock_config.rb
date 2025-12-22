require 'json'

module Verifaith
  module EditionLockConfig
    CONFIG_DIR = Rails.root.join('config', 'verifaith').freeze

    module_function

    # Load source_tradition_map.json
    # Format: { "source_code": { "book_code": "tradition_code" } }
    def source_tradition_map
      return @source_tradition_map if @source_tradition_map.is_a?(Hash)
      @source_tradition_map = ensure_hash(load_json('source_tradition_map.json'))
    end

    # Load tradition_marker_denylists.json
    # Format: { "source_code": { "tradition_code": ["marker_pattern", ...] } }
    def tradition_marker_denylists
      return @tradition_marker_denylists if @tradition_marker_denylists.is_a?(Hash)
      @tradition_marker_denylists = ensure_hash(load_json('tradition_marker_denylists.json'))
    end

    # Load allowed_end_markers.json
    # Format: { "source_code": { "book_code": { "unit_scope": ["allowed_end_token_sequence"] } } }
    def allowed_end_markers
      return @allowed_end_markers if @allowed_end_markers.is_a?(Hash)
      @allowed_end_markers = ensure_hash(load_json('allowed_end_markers.json'))
    end

    # Get expected tradition code for a source+book
    def expected_tradition_code(source_code, book_code)
      map = source_tradition_map
      return nil unless map.is_a?(Hash)
      map.dig(source_code.to_s, book_code.to_s)
    end

    # Get denylist markers for a source+tradition
    def denylist_markers(source_code, tradition_code)
      denylists = tradition_marker_denylists
      return [] unless denylists.is_a?(Hash)
      denylists.dig(source_code.to_s, tradition_code.to_s) || []
    end

    # Get allowed end markers for a source+book+unit_scope
    def allowed_end_marker_sequences(source_code, book_code, unit_scope)
      markers = allowed_end_markers
      return [] unless markers.is_a?(Hash)
      markers.dig(source_code.to_s, book_code.to_s, unit_scope.to_s) || []
    end

    # Ensure value is a Hash (defensive check)
    def ensure_hash(value)
      return {} if value.nil?
      return value if value.is_a?(Hash)
      Rails.logger.warn "Expected Hash but got #{value.class}, returning empty hash"
      {}
    end

    # Load JSON config file (module function)
    def load_json(filename)
      path = CONFIG_DIR.join(filename)
      return {} unless File.exist?(path)

      parsed = JSON.parse(File.read(path))
      ensure_hash(parsed)
    rescue JSON::ParserError, Errno::ENOENT => e
      Rails.logger.warn "Failed to load #{filename}: #{e.message}"
      {}
    end

    module_function :load_json

    # Clear cached config values (useful for testing or if cache is corrupted)
    def clear_cache!
      @source_tradition_map = nil
      @tradition_marker_denylists = nil
      @allowed_end_markers = nil
    end
  end
end

