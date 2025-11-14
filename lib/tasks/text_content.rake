namespace :text_content do
  desc "Create all text content records for a source and book (e.g., John). source_name can be ID (e.g., '1') or name"
  task :create_all, [:source_name, :book_code] => :environment do |t, args|
    # Allow source_name to be an ID (e.g., "1") or a name
    source_name = args[:source_name] || "1"  # Default to ID 1 for production
    # Default book code - try JOH first (production), fallback to JHN
    book_code = args[:book_code] || (Book.unscoped.find_by(code: 'JOH') ? 'JOH' : 'JHN')
    
    puts "=" * 80
    puts "Creating all text content records for #{source_name} - Book: #{book_code}"
    puts "=" * 80
    puts ""
    
    # Ensure book exists, create if it doesn't
    book = Book.unscoped.find_by(code: book_code)
    unless book
      puts "Book '#{book_code}' not found. Creating it..."
      book = Book.create!(
        code: book_code,
        std_name: book_code == 'JHN' ? 'John' : book_code,
        description: "Book #{book_code}"
      )
      puts "✓ Created book: #{book.code} - #{book.std_name}"
    else
      puts "✓ Using existing book: #{book.code} - #{book.std_name}"
    end
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
  
  desc "Clean up extra verses beyond expected counts. Use DRY_RUN=false to actually delete (default: DRY_RUN=true)"
  task :cleanup_extra_verses, [:source_name, :book_code] => :environment do |t, args|
    source_name = args[:source_name] || "1"  # Default to ID 10 (Westcott-Hort)
    book_code = args[:book_code] || "JOH"
    dry_run = ENV['DRY_RUN'] != 'false'  # Default to dry run for safety
    
    puts "=" * 80
    puts "Cleaning up extra verses for #{source_name} - Book: #{book_code}"
    puts "Mode: #{dry_run ? 'DRY RUN (no deletions)' : 'LIVE (will delete)'}"
    puts "=" * 80
    puts ""
    
    # Resolve source
    source = nil
    if source_name.to_i.to_s == source_name
      source = Source.unscoped.find_by(id: source_name.to_i)
    end
    source ||= Source.unscoped.find_by(name: source_name)
    source ||= Source.unscoped.where('name ILIKE ?', "%#{source_name}%").first
    
    unless source
      puts "✗ Source not found: #{source_name}"
      exit 1
    end
    
    puts "✓ Source: #{source.name} (ID: #{source.id})"
    
    # Resolve book
    book = Book.unscoped.find_by(code: book_code)
    book ||= Book.unscoped.where('LOWER(code) = LOWER(?)', book_code).first
    
    unless book
      puts "✗ Book not found: #{book_code}"
      exit 1
    end
    
    puts "✓ Book: #{book.std_name} (#{book.code})"
    puts ""
    
    # Get all records for this source and book
    all_records = TextContent.unscoped.where(
      source_id: source.id,
      book_id: book.id
    ).order(:unit_group, :unit)
    
    # Group by chapter
    records_by_chapter = all_records.group_by(&:unit_group)
    
    total_extra = 0
    chapters_with_issues = []
    
    records_by_chapter.each do |chapter, records|
      expected_count = VerseCountReference.expected_verses(book.code, chapter)
      
      if expected_count.nil?
        puts "⚠ Chapter #{chapter}: No expected count defined (found #{records.count} verses)"
        next
      end
      
      actual_count = records.count
      
      if actual_count > expected_count
        extra_count = actual_count - expected_count
        total_extra += extra_count
        
        # Find verses beyond expected count
        extra_verses = records.select { |r| r.unit > expected_count }.sort_by(&:unit)
        
        chapters_with_issues << {
          chapter: chapter,
          expected: expected_count,
          actual: actual_count,
          extra: extra_count,
          verses: extra_verses
        }
        
        puts "✗ Chapter #{chapter}: Expected #{expected_count}, found #{actual_count} (#{extra_count} extra)"
        extra_verses.each do |verse|
          puts "    - Verse #{verse.unit}: #{verse.unit_key} (ID: #{verse.id})"
        end
      elsif actual_count < expected_count
        puts "⚠ Chapter #{chapter}: Expected #{expected_count}, found #{actual_count} (missing #{expected_count - actual_count})"
      else
        puts "✓ Chapter #{chapter}: #{actual_count} verses (correct)"
      end
    end
    
    puts ""
    puts "=" * 80
    puts "Summary:"
    puts "  - Total extra verses: #{total_extra}"
    puts "  - Chapters with extra verses: #{chapters_with_issues.count}"
    puts "=" * 80
    
    if chapters_with_issues.any?
      puts ""
      if dry_run
        puts "DRY RUN MODE: No records were deleted."
        puts "To actually delete these records, run:"
        puts "  DRY_RUN=false rake 'text_content:cleanup_extra_verses[#{source_name},#{book_code}]'"
      else
        puts "LIVE MODE: Deleting extra verses..."
        deleted_count = 0
        
        chapters_with_issues.each do |issue|
          issue[:verses].each do |verse|
            begin
              # Delete associated records first (text_translations, canon_text_contents)
              verse.text_translations.destroy_all
              verse.canon_text_contents.destroy_all
              verse.child_units.update_all(parent_unit_id: nil) if verse.child_units.any?
              
              # Delete the verse
              verse.destroy
              deleted_count += 1
              puts "  ✓ Deleted: #{verse.unit_key} (ID: #{verse.id})"
            rescue => e
              puts "  ✗ Error deleting #{verse.unit_key}: #{e.message}"
            end
          end
        end
        
        puts ""
        puts "✓ Deleted #{deleted_count} extra verse(s)"
      end
    else
      puts ""
      puts "✓ No extra verses found. All chapters have correct counts."
    end
    
    puts ""
    puts "Done!"
  end
end

