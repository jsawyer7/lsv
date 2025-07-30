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
  # Each section can contain multiple items (e.g., multiple verses)
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

    # Initialize section as array if it doesn't exist
    sections[section_type] = [] unless sections[section_type]

    # Add the new section data to the array
    sections[section_type] << section_data
    set_evidence_sections(sections)
  end

  def remove_evidence_section(section_type, section_index = nil)
    sections = evidence_sections

    if section_index.nil?
      # Remove entire section type
      sections.delete(section_type)
    else
      # Remove specific item from section array
      if sections[section_type].is_a?(Array) && sections[section_type][section_index]
        sections[section_type].delete_at(section_index)
        # Remove section type if empty
        sections.delete(section_type) if sections[section_type].empty?
      end
    end

    set_evidence_sections(sections)
  end

  def get_evidence_section(section_type, section_index = nil)
    sections = evidence_sections
    section_data = sections[section_type]

    if section_index.nil?
      section_data
    elsif section_data.is_a?(Array) && section_data[section_index]
      section_data[section_index]
    else
      nil
    end
  end

  def has_evidence_section?(section_type)
    sections = evidence_sections
    sections.key?(section_type) && !sections[section_type].empty?
  end

  def get_evidence_section_count(section_type)
    sections = evidence_sections
    section_data = sections[section_type]

    if section_data.is_a?(Array)
      section_data.length
    elsif section_data
      1
    else
      0
    end
  end

  # Method to get all evidence content as text
  def evidence_content
    sections = evidence_sections
    return content if sections.empty? # Fallback to old content

    content_parts = []

    if sections['verse']
      verse_data = sections['verse']
      if verse_data.is_a?(Array)
        # Handle multiple verses
        verse_data.each_with_index do |verse, index|
          content_parts << "Verse #{index + 1}: #{verse['verse_reference']}\n\n#{verse['translation']}"
        end
      else
        # Handle single verse (backward compatibility)
        content_parts << "#{verse_data['verse_reference']}\n\n#{verse_data['translation']}"
      end
    end

    if sections['historical']
      historical_data = sections['historical']
      if historical_data.is_a?(Array)
        # Handle multiple historical events
        historical_data.each_with_index do |event, index|
          content_parts << "Historical Event #{index + 1}: #{event['historical_event']}\n\n#{event['description']}"
        end
      else
        # Handle single historical event (backward compatibility)
        content_parts << "#{historical_data['historical_event']}\n\n#{historical_data['description']}"
      end
    end

    if sections['definition']
      definition_data = sections['definition']
      if definition_data.is_a?(Array)
        # Handle multiple definitions
        definition_data.each_with_index do |def_item, index|
          content_parts << "Definition #{index + 1}: #{def_item['term']}\n\n#{def_item['definition']}"
        end
      else
        # Handle single definition (backward compatibility)
        content_parts << "#{definition_data['term']}\n\n#{definition_data['definition']}"
      end
    end

    if sections['logic']
      logic_data = sections['logic']
      if logic_data.is_a?(Array)
        # Handle multiple logic arguments
        logic_data.each_with_index do |logic_item, index|
          content_parts << "Logic #{index + 1}: #{logic_item['premise']}\n\n#{logic_item['reasoning']}\n\n#{logic_item['conclusion']}"
        end
      else
        # Handle single logic argument (backward compatibility)
        content_parts << "#{logic_data['premise']}\n\n#{logic_data['reasoning']}\n\n#{logic_data['conclusion']}"
      end
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

    # Collect all sources from all sections
    all_sources = []

    sections.each do |section_type, section_data|
      case section_type
      when 'verse'
        if section_data.is_a?(Array)
          # Handle multiple verses
          section_data.each_with_index do |verse_data, index|
            # Extract data from HTML details
            if verse_data['details']
              details_html = verse_data['details']

              # Extract verse reference
              if details_html.match(/Reference:<\/span>\s*<span[^>]*>([^<]+)</)
                verse_reference = $1.strip
                if index == 0
                  self.verse_reference = verse_reference
                end
              end

              # Extract original text
              if details_html.match(/Original Text:<\/span>\s*<span[^>]*>([^<]+)</)
                original_text = $1.strip
                if index == 0
                  self.original_text = original_text
                end
              end

              # Extract translation
              if details_html.match(/Translation:<\/span>\s*<span[^>]*>([^<]+)</)
                translation = $1.strip
                if index == 0
                  self.translation = translation
                end
              end

              # Extract explanation
              if details_html.match(/Explanation:<\/span>\s*<span[^>]*>([^<]+)</)
                explanation = $1.strip
                if index == 0
                  self.explanation = explanation
                end
              end

              # Extract sources from HTML
              if details_html.match(/Source:<\/span>\s*<span[^>]*>([^<]+)</)
                source_text = $1.strip
                # Split by comma and clean up
                source_names = source_text.split(',').map(&:strip)
                all_sources.concat(source_names)
              end
            end

            # Also check for sources in the sources array
            if verse_data['sources']
              all_sources.concat(verse_data['sources'])
            end
          end
        else
          # Handle single verse (backward compatibility)
          if section_data['details']
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

            # Extract sources from HTML
            if details_html.match(/Source:<\/span>\s*<span[^>]*>([^<]+)</)
              source_text = $1.strip
              # Split by comma and clean up
              source_names = source_text.split(',').map(&:strip)
              all_sources.concat(source_names)
            end
          end

          # Also check for sources in the sources array
          if section_data['sources']
            all_sources.concat(section_data['sources'])
          end
        end
      when 'historical'
        if section_data.is_a?(Array)
          # Handle multiple historical events
          section_data.each_with_index do |historical_data, index|
            if index == 0
              # Use first historical event for main fields (backward compatibility)
              if historical_data['details']
                details_html = historical_data['details']

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
            end

            # Collect sources from each historical event
            if historical_data['sources']
              all_sources.concat(historical_data['sources'])
            end
          end
        else
          # Handle single historical event (backward compatibility)
          if section_data['details']
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

          # Collect sources from single historical event
          if section_data['sources']
            all_sources.concat(section_data['sources'])
          end
        end
      when 'definition'
        if section_data.is_a?(Array)
          # Handle multiple definitions
          section_data.each_with_index do |definition_data, index|
            if index == 0
              # Use first definition for main fields (backward compatibility)
              if definition_data['details']
                details_html = definition_data['details']

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
            end

            # Collect sources from each definition
            if definition_data['sources']
              all_sources.concat(definition_data['sources'])
            end
          end
        else
          # Handle single definition (backward compatibility)
          if section_data['details']
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

          # Collect sources from single definition
          if section_data['sources']
            all_sources.concat(section_data['sources'])
          end
        end
      when 'logic'
        if section_data.is_a?(Array)
          # Handle multiple logic arguments
          section_data.each_with_index do |logic_data, index|
            if index == 0
              # Use first logic argument for main fields (backward compatibility)
              if logic_data['details']
                details_html = logic_data['details']

                if details_html.match(/Premise:<\/span>\s*<span[^>]*>([^<]+)</)
                  self.premise = $1.strip
                end

                if details_html.match(/Reasoning:<\/span>\s*<span[^>]*>([^<]+)</)
                  self.reasoning = $1.strip
                end

                if details_html.match(/Conclusion:<\/span>\s*<span[^>]*>([^<]+)</)
                  self.conclusion = $1.strip
                end
              end
            end

            # Collect sources from each logic argument
            if logic_data['sources']
              all_sources.concat(logic_data['sources'])
            end
          end
        else
          # Handle single logic argument (backward compatibility)
          if section_data['details']
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
          end

          # Collect sources from single logic argument
          if section_data['sources']
            all_sources.concat(section_data['sources'])
          end
        end
      end
    end

    # Convert all collected sources to enums and store in sources array
    if all_sources.any?
      source_enums = all_sources.map { |s| AVAILABLE_SOURCES[s.downcase] }.compact.uniq
      self.sources = source_enums if source_enums.any?
    end
  end
end
