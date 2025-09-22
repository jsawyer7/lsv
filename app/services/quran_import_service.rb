class QuranImportService
  require 'nokogiri'
  require 'digest'
  require 'securerandom'
  
  def initialize
    @quran_data_dir = Rails.root.join('data', 'quran')
    @source_registry = nil
    @sequence_index = 0
  end
  
  def import_quran
    puts "Starting Quran import..."
    
    # Step 1: Create source registry entry
    create_source_registry
    
    # Step 2: Parse XML files
    quran_text = parse_quran_text
    quran_metadata = parse_quran_metadata
    
    # Step 3: Create text units and payloads
    create_text_units_and_payloads(quran_text, quran_metadata)
    
    puts "Quran import completed successfully!"
    puts "Total verses imported: #{TextUnit.count}"
    puts "Total payloads created: #{TextPayload.count}"
  end
  
  def verify_integrity
    puts "Verifying data integrity..."
    
    errors = []
    
    # Check that all payloads have valid checksums
    TextPayload.find_each do |payload|
      unless payload.verify_checksum
        errors << "Invalid checksum for payload #{payload.payload_id}"
      end
    end
    
    # Check that all text units have payloads
    TextUnit.find_each do |unit|
      unless unit.text_payloads.exists?
        errors << "Text unit #{unit.unit_id} has no payloads"
      end
    end
    
    # Check that all text units are in canon map
    TextUnit.find_each do |unit|
      unless unit.canon_maps.exists?
        errors << "Text unit #{unit.unit_id} is not in canon map"
      end
    end
    
    if errors.empty?
      puts "✅ All integrity checks passed!"
    else
      puts "❌ Integrity check failed:"
      errors.each { |error| puts "  - #{error}" }
    end
    
    errors
  end
  
  def clear_quran_data
    puts "Clearing Quran data..."
    
    # Clear in reverse dependency order using delete_all to avoid callbacks
    TextPayload.delete_all
    CanonMap.delete_all
    TextUnit.delete_all
    SourceRegistry.delete_all
    
    puts "Quran data cleared."
  end
  
  private
  
  def create_source_registry
    puts "Creating source registry entry..."
    
    # Generate checksums for the XML files (try actual files first, fall back to sample)
    uthmani_checksum = generate_file_checksum('quran-uthmani.xml') || generate_file_checksum('quran-uthmani-sample.xml')
    data_checksum = generate_file_checksum('quran-data.xml') || generate_file_checksum('quran-data-sample.xml')
    
    # Determine if we're using sample or actual data
    is_sample = !File.exist?(@quran_data_dir.join('quran-uthmani.xml'))
    source_name = is_sample ? 'Tanzil Uthmani (Sample)' : 'Tanzil Uthmani'
    notes = is_sample ? 
      "Sample Quran data for testing. Uthmani checksum: #{uthmani_checksum}, Data checksum: #{data_checksum}" :
      "Tanzil Uthmani Quran data. Uthmani checksum: #{uthmani_checksum}, Data checksum: #{data_checksum}"
    
    @source_registry = SourceRegistry.create!(
      source_id: generate_ulid,
      name: source_name,
      publisher: 'Tanzil Project',
      contact: 'https://tanzil.net/',
      license: 'CC BY 3.0',
      url: 'https://tanzil.net/',
      version: '1.1',
      checksum_sha256: uthmani_checksum,
      notes: notes
    )
    
    puts "Source registry created: #{@source_registry.source_id}"
  end
  
  def parse_quran_text
    puts "Parsing Quran text XML..."
    
    # Try to use the actual file first, fall back to sample
    file_path = @quran_data_dir.join('quran-uthmani.xml')
    unless File.exist?(file_path)
      file_path = @quran_data_dir.join('quran-uthmani-sample.xml')
    end
    
    doc = Nokogiri::XML(File.read(file_path))
    
    quran_text = {}
    
    doc.xpath('//sura').each do |sura|
      sura_index = sura['index'].to_i
      sura_name = sura['name']
      
      quran_text[sura_index] = {}
      
      sura.xpath('aya').each do |aya|
        ayah_index = aya['index'].to_i
        text = aya['text']
        
        quran_text[sura_index][ayah_index] = {
          text: text,
          sura_name: sura_name
        }
      end
    end
    
    puts "Parsed #{quran_text.values.sum { |sura| sura.keys.length }} verses"
    quran_text
  end
  
  def parse_quran_metadata
    puts "Parsing Quran metadata XML..."
    
    # Try to use the actual file first, fall back to sample
    file_path = @quran_data_dir.join('quran-data.xml')
    unless File.exist?(file_path)
      file_path = @quran_data_dir.join('quran-data-sample.xml')
    end
    
    # If no metadata file exists, return empty metadata
    unless File.exist?(file_path)
      puts "⚠️  No metadata file found. Proceeding without metadata (page, juz, hizb, sajda info will be missing)."
      return {}
    end
    
    doc = Nokogiri::XML(File.read(file_path))
    
    quran_metadata = {}
    
    doc.xpath('//sura').each do |sura|
      sura_index = sura['index'].to_i
      
      quran_metadata[sura_index] = {}
      
      sura.xpath('aya').each do |aya|
        ayah_index = aya['index'].to_i
        
        quran_metadata[sura_index][ayah_index] = {
          page: aya['page']&.to_i,
          juz: aya['juz']&.to_i,
          hizb: aya['hizb']&.to_i,
          rub: aya['rub']&.to_i,
          sajda: aya['sajda'] == 'true',
          ruku: aya['ruku']&.to_i,
          manzil: aya['manzil']&.to_i
        }
      end
    end
    
    puts "Parsed metadata for #{quran_metadata.values.sum { |sura| sura.keys.length }} verses"
    quran_metadata
  end
  
  def create_text_units_and_payloads(quran_text, quran_metadata)
    puts "Creating text units and payloads..."
    
    @sequence_index = 0
    
    quran_text.each do |sura_index, sura_data|
      sura_data.each do |ayah_index, ayah_data|
        @sequence_index += 1
        
        # Create text unit
        unit_id = generate_ulid
        division_code = TextUnit.surah_name(sura_index)
        
        text_unit = TextUnit.create!(
          unit_id: unit_id,
          tradition: TextUnit::QURAN_TRADITION,
          work_code: TextUnit::QURAN_WORK_CODE,
          division_code: division_code,
          chapter: sura_index,
          verse: ayah_index,
          subref: nil
        )
        
        # Create canon map
        CanonMap.create!(
          canon_id: CanonMap::QURAN_CANON_ID,
          unit_id: unit_id,
          sequence_index: @sequence_index
        )
        
        # Create text payload
        content = TextPayload.normalize_arabic(ayah_data[:text])
        checksum = TextPayload.generate_checksum(content)
        metadata = quran_metadata.dig(sura_index, ayah_index) || {}
        
        TextPayload.create!(
          payload_id: generate_ulid,
          unit_id: unit_id,
          language: TextPayload::QURAN_LANGUAGE,
          script: TextPayload::QURAN_SCRIPT,
          edition_id: TextPayload::QURAN_EDITION_ID,
          layer: TextPayload::QURAN_LAYER,
          content: content,
          meta: metadata,
          checksum_sha256: checksum,
          source_id: @source_registry.source_id,
          license: TextPayload::QURAN_LICENSE,
          version: '1.1'
        )
        
        puts "  Created: #{division_code} #{sura_index}:#{ayah_index}"
      end
    end
  end
  
  def generate_file_checksum(filename)
    file_path = @quran_data_dir.join(filename)
    return 'file_not_found' unless File.exist?(file_path)
    
    Digest::SHA256.hexdigest(File.read(file_path))
  end
  
  def generate_ulid
    # Generate a ULID-like identifier (26 characters)
    # Using a simplified version for this implementation
    timestamp = Time.now.to_i.to_s(36)
    random = SecureRandom.hex(8)
    "#{timestamp}#{random}".upcase[0..25]
  end
end
