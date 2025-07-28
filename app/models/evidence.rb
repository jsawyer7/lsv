class Evidence < ApplicationRecord
  belongs_to :claim
  has_many :challenges, dependent: :destroy

  # Use a constant for available sources
  AVAILABLE_SOURCES = {
    'quran' => 0,
    'tanakh' => 1,
    'catholic' => 2,
    'ethiopian' => 3,
    'protestant' => 4,
    'historical' => 5
  }.freeze

  def source_names
    (sources || []).map { |s| AVAILABLE_SOURCES.key(s) }.compact
  end

  def add_source(source_name)
    source_enum = AVAILABLE_SOURCES[source_name]
    return unless source_enum
    self.sources = ((sources || []) + [source_enum]).uniq
  end

  def remove_source(source_name)
    source_enum = AVAILABLE_SOURCES[source_name]
    return unless source_enum
    self.sources = (sources || []) - [source_enum]
  end

  def has_source?(source_name)
    source_enum = AVAILABLE_SOURCES[source_name]
    return false unless source_enum
    (sources || []).include?(source_enum)
  end

  # Methods to handle structured evidence data
  # An evidence can contain multiple sections, so we store them as JSON in content
  def evidence_sections
    return {} unless content.present?

    begin
      JSON.parse(content)
    rescue JSON::ParserError
      # Fallback to old format
      { 'combined' => content }
    end
  end

  def set_evidence_sections(sections_data)
    self.content = sections_data.to_json
  end

  def add_evidence_section(section_type, section_data)
    sections = evidence_sections
    sections[section_type] = section_data
    set_evidence_sections(sections)
  end

  def remove_evidence_section(section_type)
    sections = evidence_sections
    sections.delete(section_type)
    set_evidence_sections(sections)
  end

  def get_evidence_section(section_type)
    evidence_sections[section_type]
  end

  def has_evidence_section?(section_type)
    evidence_sections.key?(section_type)
  end

  # Method to get all evidence content as text
  def evidence_content
    sections = evidence_sections
    return content if sections.empty? # Fallback to old content

    content_parts = []

    if sections['verse']
      verse_data = sections['verse']
      content_parts << "#{verse_data['verse_reference']}\n\n#{verse_data['translation']}"
    end

    if sections['historical']
      historical_data = sections['historical']
      content_parts << "#{historical_data['historical_event']}\n\n#{historical_data['description']}"
    end

    if sections['definition']
      definition_data = sections['definition']
      content_parts << "#{definition_data['term']}\n\n#{definition_data['definition']}"
    end

    if sections['logic']
      logic_data = sections['logic']
      content_parts << "#{logic_data['premise']}\n\n#{logic_data['reasoning']}\n\n#{logic_data['conclusion']}"
    end

    content_parts.join("\n\n---\n\n")
  end

  # Method to determine source from evidence sections
  def determine_source_from_sections
    sections = evidence_sections

    # First check if we have sources in the array
    if self.sources.present? && self.sources.any?
      source_enum = self.sources.first
      return AVAILABLE_SOURCES.key(source_enum) if source_enum
    end

    # Check verse section first as it's most likely to have source info
    if sections['verse'] && sections['verse']['source']
      return sections['verse']['source']
    end

    # Check other sections for source
    sections.each do |section_type, section_data|
      if section_data['source']
        return section_data['source']
      end
    end

    # Default to historical if no source found
    'historical'
  end

  # Method to update sources based on evidence sections
  def update_sources_from_sections
    source = determine_source_from_sections
    source_enum = AVAILABLE_SOURCES[source.downcase]
    if source_enum
      self.sources = [source_enum]
    else
      self.sources = [AVAILABLE_SOURCES[:historical]]
    end
  end

  # Method to extract and populate structured fields from JSON content
  def populate_structured_fields
    sections = evidence_sections
    return if sections.empty?

    sections.each do |section_type, section_data|
      case section_type
      when 'verse'
        # Extract data from the section_data directly
        self.verse_reference = section_data['verse_reference']
        self.original_text = section_data['original_text']
        self.translation = section_data['translation']
        self.explanation = section_data['explanation']

        # If the above fields are nil, try to extract from details HTML
        if self.verse_reference.nil? && section_data['details']
          # Parse the details HTML to extract structured data
          details_html = section_data['details']

          # Extract verse reference
          if details_html.match(/Reference:<\/span>\s*<span[^>]*>([^<]+)</)
            self.verse_reference = $1.strip
          end

          # Extract original text
          if details_html.match(/Original Text:<\/span>\s*<span[^>]*>([^<]+)</)
            self.original_text = $1.strip
          end

          # Extract translation
          if details_html.match(/Translation:<\/span>\s*<span[^>]*>([^<]+)</)
            self.translation = $1.strip
          end

          # Extract explanation
          if details_html.match(/Explanation:<\/span>\s*<span[^>]*>([^<]+)</)
            self.explanation = $1.strip
          end
        end

        # Store source in the sources array
        if section_data['source']
          source_enum = AVAILABLE_SOURCES[section_data['source'].downcase]
          self.sources = [source_enum] if source_enum
        end
      when 'historical'
        self.historical_event = section_data['historical_event']
        self.description = section_data['description']
        self.relevance = section_data['relevance']

        # If the above fields are nil, try to extract from details HTML
        if self.historical_event.nil? && section_data['details']
          details_html = section_data['details']

          if details_html.match(/Historical Event:<\/span>\s*<span[^>]*>([^<]+)</)
            self.historical_event = $1.strip
          end

          if details_html.match(/Description:<\/span>\s*<span[^>]*>([^<]+)</)
            self.description = $1.strip
          end

          if details_html.match(/Relevance:<\/span>\s*<span[^>]*>([^<]+)</)
            self.relevance = $1.strip
          end
        end

        # Store source in the sources array
        if section_data['source']
          source_enum = AVAILABLE_SOURCES[section_data['source'].downcase]
          self.sources = [source_enum] if source_enum
        end
      when 'definition'
        self.term = section_data['term']
        self.definition = section_data['definition']
        self.etymology = section_data['etymology']
        self.usage_context = section_data['usage_context']

        # If the above fields are nil, try to extract from details HTML
        if self.term.nil? && section_data['details']
          details_html = section_data['details']

          if details_html.match(/Term:<\/span>\s*<span[^>]*>([^<]+)</)
            self.term = $1.strip
          end

          if details_html.match(/Definition:<\/span>\s*<span[^>]*>([^<]+)</)
            self.definition = $1.strip
          end

          if details_html.match(/Etymology:<\/span>\s*<span[^>]*>([^<]+)</)
            self.etymology = $1.strip
          end

          if details_html.match(/Usage Context:<\/span>\s*<span[^>]*>([^<]+)</)
            self.usage_context = $1.strip
          end
        end

        # Store source in the sources array
        if section_data['source']
          source_enum = AVAILABLE_SOURCES[section_data['source'].downcase]
          self.sources = [source_enum] if source_enum
        end
      when 'logic'
        self.premise = section_data['premise']
        self.reasoning = section_data['reasoning']
        self.conclusion = section_data['conclusion']
        self.logical_form = section_data['logical_form']

        # If the above fields are nil, try to extract from details HTML
        if self.premise.nil? && section_data['details']
          details_html = section_data['details']

          if details_html.match(/Premise:<\/span>\s*<span[^>]*>([^<]+)</)
            self.premise = $1.strip
          end

          if details_html.match(/Reasoning:<\/span>\s*<span[^>]*>([^<]+)</)
            self.reasoning = $1.strip
          end

          if details_html.match(/Conclusion:<\/span>\s*<span[^>]*>([^<]+)</)
            self.conclusion = $1.strip
          end

          if details_html.match(/Logical Form:<\/span>\s*<span[^>]*>([^<]+)</)
            self.logical_form = $1.strip
          end
        end

        # Store source in the sources array
        if section_data['source']
          source_enum = AVAILABLE_SOURCES[section_data['source'].downcase]
          self.sources = [source_enum] if source_enum
        end
      end
    end
  end
end
