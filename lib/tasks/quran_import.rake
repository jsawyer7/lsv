namespace :quran_import do
  desc "Import Quran text from XML files"
  task import: :environment do
    puts "Quran Import Service"
    puts "=" * 40
    
    service = QuranImportService.new
    
    # Check if data already exists
    if TextUnit.exists?
      puts "⚠️  Quran data already exists in the database."
      print "Do you want to clear existing data and reimport? (y/n): "
      response = STDIN.gets.chomp.downcase
      
      if response == 'y'
        puts "\nClearing existing data..."
        service.clear_quran_data
      else
        puts "Import cancelled."
        exit 0
      end
    end
    
    # Perform import
    begin
      service.import_quran
      
      puts "\n" + "=" * 40
      puts "Import completed successfully!"
      puts "=" * 40
      
      # Show final counts
      puts "Final counts:"
      puts "  Text Units: #{TextUnit.count}"
      puts "  Canon Maps: #{CanonMap.count}"
      puts "  Text Payloads: #{TextPayload.count}"
      puts "  Source Registries: #{SourceRegistry.count}"
      
    rescue => e
      puts "\n❌ Import failed: #{e.message}"
      puts e.backtrace.first(5).join("\n")
      exit 1
    end
  end
  
  desc "Verify Quran data integrity"
  task verify: :environment do
    puts "Quran Data Integrity Verification"
    puts "=" * 40
    
    service = QuranImportService.new
    errors = service.verify_integrity
    
    if errors.empty?
      puts "\n✅ All integrity checks passed!"
      exit 0
    else
      puts "\n❌ Integrity verification failed with #{errors.length} errors."
      exit 1
    end
  end
  
  desc "Clear all Quran data"
  task clear: :environment do
    puts "Clearing Quran data..."
    
    service = QuranImportService.new
    service.clear_quran_data
    
    puts "Quran data cleared successfully."
  end
  
  desc "Show Quran data statistics"
  task stats: :environment do
    puts "Quran Data Statistics"
    puts "=" * 40
    
    puts "Text Units: #{TextUnit.count}"
    puts "Canon Maps: #{CanonMap.count}"
    puts "Text Payloads: #{TextPayload.count}"
    puts "Source Registries: #{SourceRegistry.count}"
    
    if TextUnit.exists?
      puts "\nSurahs covered:"
      surahs = TextUnit.distinct.pluck(:chapter).sort
      puts "  Surahs: #{surahs.join(', ')}"
      puts "  Total surahs: #{surahs.length}"
      
      puts "\nVerses per surah:"
      surahs.each do |surah|
        count = TextUnit.where(chapter: surah).count
        surah_name = TextUnit.surah_name(surah)
        puts "  #{surah_name} (#{surah}): #{count} verses"
      end
      
      puts "\nSample verses:"
      TextUnit.limit(3).each do |unit|
        payload = unit.text_payloads.first
        if payload
          puts "  #{unit.division_code} #{unit.chapter}:#{unit.verse}: #{payload.content[0..50]}..."
        end
      end
    end
  end
  
  desc "Generate checksums for Quran XML files"
  task checksums: :environment do
    puts "Generating checksums for Quran XML files"
    puts "=" * 40
    
    quran_dir = Rails.root.join('data', 'quran')
    
    ['quran-uthmani-sample.xml', 'quran-data-sample.xml'].each do |filename|
      file_path = quran_dir.join(filename)
      
      if File.exist?(file_path)
        checksum = Digest::SHA256.hexdigest(File.read(file_path))
        puts "#{filename}: #{checksum}"
      else
        puts "#{filename}: FILE NOT FOUND"
      end
    end
  end
end
