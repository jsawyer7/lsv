class NameNormalizationService
  def initialize
    @lookup_cache = nil
  end

  # Normalize text by replacing names with internal IDs
  def normalize_text(text)
    return text if text.blank?

    normalized_text = text.dup
    
    # Get all name mappings and create lookup
    lookup = build_lookup
    
    # Replace each name variation with its internal ID
    lookup.each do |name_variation, internal_id|
      # Use word boundaries to avoid partial matches
      pattern = /\b#{Regexp.escape(name_variation)}\b/i
      normalized_text.gsub!(pattern, "{#{internal_id}}")
    end
    
    normalized_text
  end

  # Denormalize text by replacing internal IDs with names for a specific tradition
  def denormalize_text(text, tradition = 'actual')
    return text if text.blank?

    denormalized_text = text.dup
    
    # Find all internal ID placeholders
    internal_ids = text.scan(/\{([^}]+)\}/).flatten
    
    internal_ids.each do |internal_id|
      mapping = NameMapping.find_by(internal_id: internal_id)
      if mapping
        replacement_name = mapping.name_for_tradition(tradition)
        denormalized_text.gsub!("{#{internal_id}}", replacement_name)
      end
    end
    
    denormalized_text
  end

  # Generate normalized hash for duplicate detection
  def generate_normalized_hash(text)
    normalized_text = normalize_text(text)
    Digest::SHA256.hexdigest(normalized_text.downcase.strip)
  end

  # Check if text contains any mapped names
  def contains_mapped_names?(text)
    return false if text.blank?
    
    lookup = build_lookup
    lookup.keys.any? { |name| text.downcase.include?(name.downcase) }
  end

  # Get all internal IDs found in text
  def extract_internal_ids(text)
    return [] if text.blank?
    
    internal_ids = text.scan(/\{([^}]+)\}/).flatten
    internal_ids.uniq
  end

  # Get all name variations for a given internal ID
  def get_name_variations(internal_id)
    mapping = NameMapping.find_by(internal_id: internal_id)
    mapping&.all_variations || []
  end

  private

  def build_lookup
    return @lookup_cache if @lookup_cache

    @lookup_cache = {}
    
    NameMapping.find_each do |mapping|
      mapping.all_variations.each do |variation|
        next if variation.blank?
        @lookup_cache[variation.downcase] = mapping.internal_id
      end
    end
    
    @lookup_cache
  end
end 