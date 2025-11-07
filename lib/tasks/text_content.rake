namespace :text_content do
  desc "Create all text content records for a source and book (e.g., John). source_name can be ID (e.g., '1') or name"
  task :create_all, [:source_name, :book_code] => :environment do |t, args|
    # Allow source_name to be an ID (e.g., "1") or a name
    source_name = args[:source_name] || "1"  # Default to ID 1 for production
    book_code = args[:book_code] || "JHN"
    
    puts "=" * 80
    puts "Creating all text content records for #{source_name} - Book: #{book_code}"
    puts "=" * 80
    puts ""
    
    # Start with chapter 1, verse 1
    current_chapter = 1
    current_verse = 1
    total_created = 0
    total_existing = 0
    errors = []
    
    loop do
      service = TextContentCreationService.new(
        source_name: source_name,
        current_book_code: book_code,
        current_chapter: current_chapter,
        current_verse: current_verse
      )
      
      result = service.create_next
      
      case result[:status]
      when 'created'
        total_created += 1
        created = result[:created]
        puts "✓ Created: #{created[:book_code]} #{created[:chapter]}:#{created[:verse]} (#{created[:unit_key]})"
        current_chapter = created[:chapter]
        current_verse = created[:verse]
        
      when 'exists'
        total_existing += 1
        existing = result[:created] || result[:existing]
        puts "→ Exists: #{existing[:book_code]} #{existing[:chapter]}:#{existing[:verse]} (#{existing[:unit_key]})"
        current_chapter = existing[:chapter]
        current_verse = existing[:verse]
        
      when 'complete'
        puts ""
        puts "=" * 80
        puts "✓ Complete! Reached end of #{book_code}"
        puts "=" * 80
        break
        
      when 'error'
        error_msg = result[:error] || "Unknown error"
        errors << "#{book_code} #{current_chapter}:#{current_verse} - #{error_msg}"
        puts "✗ Error: #{book_code} #{current_chapter}:#{current_verse} - #{error_msg}"
        
        # Try to continue from next verse if possible
        current_verse += 1
        if current_verse > 100  # Safety limit - assume chapter is done
          current_chapter += 1
          current_verse = 1
          if current_chapter > 50  # Safety limit - assume book is done
            puts ""
            puts "=" * 80
            puts "⚠ Stopped due to errors (reached safety limits)"
            puts "=" * 80
            break
          end
        end
      end
      
      # Small delay to avoid overwhelming the API
      sleep 0.5
    end
    
    puts ""
    puts "Summary:"
    puts "  - Total created: #{total_created}"
    puts "  - Total existing: #{total_existing}"
    puts "  - Errors: #{errors.count}"
    
    if errors.any?
      puts ""
      puts "Errors encountered:"
      errors.each { |e| puts "  - #{e}" }
    end
    
    puts ""
    puts "Done!"
  end
  
  desc "Show statistics for text content records"
  task :stats, [:source_name] => :environment do |t, args|
    source_name = args[:source_name] || "Greek New Testament (Westcott–Hort 1881)"
    
    source = Source.find_by(name: source_name)
    unless source
      puts "Source not found: #{source_name}"
      exit 1
    end
    
    records = TextContent.where(source_id: source.id).order(:unit_key)
    
    puts "=" * 80
    puts "Text Content Statistics for: #{source_name}"
    puts "=" * 80
    puts ""
    puts "Total records: #{records.count}"
    
    if records.any?
      puts ""
      puts "By Book:"
      records.group_by(&:book).each do |book, book_records|
        puts "  - #{book.std_name} (#{book.code}): #{book_records.count} records"
      end
      
      puts ""
      puts "First 10 records:"
      records.limit(10).each do |tc|
        puts "  - #{tc.unit_key} (#{tc.book.std_name} #{tc.unit_group}:#{tc.unit})"
      end
      
      puts ""
      puts "Last 10 records:"
      records.offset([records.count - 10, 0].max).each do |tc|
        puts "  - #{tc.unit_key} (#{tc.book.std_name} #{tc.unit_group}:#{tc.unit})"
      end
    end
  end
end

