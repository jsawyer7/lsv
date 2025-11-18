namespace :text_content do
  desc "Create all text content records for a source and book (e.g., John). source_name can be ID (e.g., '1') or name"
  task :create_all, [:source_name, :book_code] => :environment do |t, args|
    # Allow source_name to be an ID (e.g., "1") or a name
    source_name = args[:source_name] || "10"  # Default to ID 1 for production
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
  
  desc "Populate and validate content for a specific verse (e.g., John 1:1). Usage: rake 'text_content:populate_and_validate[source_id,book_code,chapter,verse]' or use FORCE=true to overwrite existing content"
  task :populate_and_validate, [:source_id, :book_code, :chapter, :verse] => :environment do |t, args|
    source_id = args[:source_id] || "10"
    book_code = args[:book_code] || "JHN"
    chapter = args[:chapter]&.to_i || 1
    verse = args[:verse]&.to_i || 1
    force = ENV['FORCE'] == 'true'
    
    puts "=" * 80
    puts "Populating and Validating Content"
    puts "Source ID: #{source_id}, Book: #{book_code}, Chapter: #{chapter}, Verse: #{verse}"
    puts "=" * 80
    puts ""
    
    # Find the text content record
    source = Source.unscoped.find_by(id: source_id.to_i)
    unless source
      puts "✗ Source not found: #{source_id}"
      exit 1
    end
    
    book = Book.unscoped.find_by(code: book_code) || Book.unscoped.where('LOWER(code) = LOWER(?)', book_code).first
    unless book
      puts "✗ Book not found: #{book_code}"
      exit 1
    end
    
    text_content = TextContent.unscoped.find_by(
      source_id: source.id,
      book_id: book.id,
      unit_group: chapter,
      unit: verse
    )
    
    unless text_content
      puts "✗ Text Content not found: #{book.std_name} #{chapter}:#{verse}"
      puts "   Please create the record first using: rake 'text_content:create_all[#{source_id},#{book_code}]'"
      exit 1
    end
    
    puts "✓ Found: #{text_content.unit_key}"
    puts ""
    
    # Step 1: Populate content
    puts "Step 1: Populating content fields..."
    puts "-" * 80
    if force
      puts "⚠ FORCE mode: Will overwrite existing content if present"
    end
    puts ""
    
    population_service = TextContentPopulationService.new(text_content)
    population_result = population_service.populate_content_fields(force: force)
    
    if population_result[:status] == 'success'
      puts "✓ Content populated successfully"
      if population_result[:overwrote]
        puts "  ⚠ Overwrote existing content"
      end
      puts "  - Source text length: #{text_content.reload.content&.length || 0} characters"
      puts "  - Word-for-word entries: #{text_content.word_for_word_translation&.count || 0}"
      puts "  - LSV Literal Reconstruction: #{text_content.lsv_literal_reconstruction.present? ? 'Yes' : 'No'}"
      puts "  - Populated at: #{text_content.content_populated_at}"
    elsif population_result[:status] == 'already_populated'
      puts "→ Content already populated (skipped)"
      puts "  - Previously populated at: #{population_result[:content_populated_at]}"
      puts "  - To overwrite, run with: FORCE=true rake 'text_content:populate_and_validate[#{source_id},#{book_code},#{chapter},#{verse}]'"
      puts ""
      puts "Skipping validation since content was not updated."
      puts "Done!"
      exit 0
    else
      puts "✗ Failed to populate content: #{population_result[:error]}"
      exit 1
    end
    
    puts ""
    
    # Step 2: Validate content
    puts "Step 2: Validating content accuracy..."
    puts "-" * 80
    validation_service = TextContentValidationService.new(text_content.reload)
    validation_result = validation_service.validate_content
    
    if validation_result[:status] == 'success'
      text_content.reload
      is_accurate = validation_result[:is_accurate]
      accuracy = validation_result[:accuracy_percentage] || 0
      
      character_accurate = validation_result[:character_accurate] != false
      has_lsv_violations = validation_result[:lsv_rule_violations]&.any?
      
      if is_accurate && !has_lsv_violations
        puts "✓ Validation successful"
      elsif character_accurate && has_lsv_violations
        puts "⚠ Validation: Characters accurate but LSV rule violations found"
      else
        puts "✗ Validation found issues"
      end
      
      puts "  - Character accuracy: #{accuracy}%"
      puts "  - Characters match: #{character_accurate ? 'Yes' : 'No'}"
      puts "  - LSV rules compliant: #{has_lsv_violations ? 'No' : 'Yes'}"
      puts "  - Overall 100% accurate: #{is_accurate ? 'Yes' : 'No'}"
      
      if validation_result[:discrepancies]&.any?
        puts "  - Discrepancies found: #{validation_result[:discrepancies].count}"
        validation_result[:discrepancies].first(5).each do |disc|
          puts "    * #{disc['type']}: Expected '#{disc['expected']}', Found '#{disc['found']}'"
        end
      end
      
      if validation_result[:lsv_rule_violations]&.any?
        puts "  - LSV Rule Violations found: #{validation_result[:lsv_rule_violations].count}"
        validation_result[:lsv_rule_violations].each do |violation|
          puts "    * Word: '#{violation['word']}'"
          puts "      Type: #{violation['violation_type']}"
          puts "      Issue: #{violation['issue']}"
          puts "      Comment: #{violation['comment'][0..100]}..."
        end
      end
      
      puts "  - Validated at: #{text_content.content_validated_at}"
      
      if validation_result[:validation_notes].present?
        puts "  - Notes: #{validation_result[:validation_notes][0..200]}..."
      end
    else
      puts "✗ Validation failed: #{validation_result[:error]}"
    end
    
    puts ""
    puts "=" * 80
    puts "Summary:"
    puts "  - Unit Key: #{text_content.unit_key}"
    puts "  - Content: #{text_content.content.present? ? 'Populated' : 'Not populated'}"
    puts "  - Word-for-Word: #{text_content.word_for_word_translation&.count || 0} entries"
    puts "  - LSV Literal: #{text_content.lsv_literal_reconstruction.present? ? 'Yes' : 'No'}"
    puts "  - Validation: #{text_content.content_validated_at ? 'Completed' : 'Not validated'}"
    if text_content.content_validation_result
      result = text_content.content_validation_result
      puts "  - Accuracy: #{result['accuracy_percentage']}%"
      puts "  - 100% Accurate: #{result['is_accurate'] ? 'Yes' : 'No'}"
    end
    puts "=" * 80
    puts ""
    puts "Done!"
  end
  
  desc "Populate and validate content for ALL verses of John. Usage: rake 'text_content:populate_all_john[source_id]' or use FORCE=true to overwrite existing content"
  task :populate_all_john, [:source_id] => :environment do |t, args|
    source_id = args[:source_id] || "10"
    force = ENV['FORCE'] == 'true'
    
    puts "=" * 80
    puts "Populating and Validating ALL John Verses"
    puts "Source ID: #{source_id}"
    puts "Mode: #{force ? 'FORCE (will overwrite existing)' : 'Normal (skip existing)'}"
    puts "=" * 80
    puts ""
    
    # Find source
    source = Source.unscoped.find_by(id: source_id.to_i)
    unless source
      puts "✗ Source not found: #{source_id}"
      exit 1
    end
    
    puts "✓ Source: #{source.name} (ID: #{source.id})"
    
    # Find John book (try both JHN and JOH codes)
    book = Book.unscoped.find_by(code: 'JHN') || Book.unscoped.find_by(code: 'JOH')
    unless book
      puts "✗ Book 'John' not found (tried JHN and JOH)"
      exit 1
    end
    
    puts "✓ Book: #{book.std_name} (#{book.code})"
    puts ""
    
    # Get all existing TextContent records for John
    existing_records = TextContent.unscoped.where(
      source_id: source.id,
      book_id: book.id
    ).order(:unit_group, :unit)
    
    puts "Found #{existing_records.count} existing TextContent records for John"
    puts ""
    
    # Verify we have all expected verses
    expected_verses_by_chapter = VerseCountReference::JOHN_CHAPTER_VERSES
    total_expected = expected_verses_by_chapter.values.sum
    
    puts "Expected verses: #{total_expected} across #{expected_verses_by_chapter.keys.count} chapters"
    puts ""
    
    # Check for missing verses
    records_by_chapter = existing_records.group_by(&:unit_group)
    missing_verses = []
    
    expected_verses_by_chapter.each do |chapter, expected_count|
      chapter_records = records_by_chapter[chapter] || []
      existing_verses = chapter_records.map(&:unit).sort
      expected_verses = (1..expected_count).to_a
      missing = expected_verses - existing_verses
      
      if missing.any?
        missing.each do |verse|
          missing_verses << { chapter: chapter, verse: verse }
        end
      end
    end
    
    if missing_verses.any?
      puts "⚠ WARNING: Missing #{missing_verses.count} verse(s):"
      missing_verses.first(10).each do |mv|
        puts "  - Chapter #{mv[:chapter]}, Verse #{mv[:verse]}"
      end
      if missing_verses.count > 10
        puts "  ... and #{missing_verses.count - 10} more"
      end
      puts ""
      puts "Please create missing records first using: rake 'text_content:create_all[#{source_id},#{book.code}]'"
      puts ""
    end
    
    # Statistics tracking
    stats = {
      total: existing_records.count,
      already_populated: 0,
      populated: 0,
      overwritten: 0,
      validated: 0,
      validation_passed: 0,
      validation_failed: 0,
      errors: [],
      lsv_violations: 0
    }
    
    puts "=" * 80
    puts "Starting population and validation..."
    puts "=" * 80
    puts ""
    
    # Process each record
    existing_records.each_with_index do |text_content, index|
      chapter = text_content.unit_group
      verse = text_content.unit
      progress = "[#{index + 1}/#{existing_records.count}]"
      
      puts "#{progress} Processing: #{book.std_name} #{chapter}:#{verse} (#{text_content.unit_key})"
      
      # Step 1: Populate (with retry for network errors)
      populate_success = false
      max_populate_retries = 3
      populate_retry_count = 0
      
      begin
        while populate_retry_count < max_populate_retries && !populate_success
          begin
            population_service = TextContentPopulationService.new(text_content)
            population_result = population_service.populate_content_fields(force: force)
            
            if population_result[:status] == 'success'
              populate_success = true
              if population_result[:overwrote]
                stats[:overwritten] += 1
                puts "  ✓ Populated (overwrote existing)"
              else
                stats[:populated] += 1
                puts "  ✓ Populated"
              end
            elsif population_result[:status] == 'already_populated'
              populate_success = true
              stats[:already_populated] += 1
              puts "  → Already populated (skipped)"
            else
              # Check if it's a retryable network error
              error_msg = population_result[:error] || ''
              is_network_error = error_msg.include?('ConnectionFailed') || 
                                 error_msg.include?('No route to host') ||
                                 error_msg.include?('Timeout') ||
                                 error_msg.include?('ECONNREFUSED') ||
                                 error_msg.include?('EHOSTUNREACH')
              
              if is_network_error && populate_retry_count < max_populate_retries - 1
                populate_retry_count += 1
                wait_time = populate_retry_count * 2
                puts "  ⚠ Network error (retry #{populate_retry_count}/#{max_populate_retries}): #{error_msg[0..100]}"
                puts "  → Waiting #{wait_time}s before retry..."
                sleep wait_time
                next
              else
                stats[:errors] << { chapter: chapter, verse: verse, error: population_result[:error], type: 'population' }
                puts "  ✗ Population failed: #{population_result[:error]}"
                break
              end
            end
          rescue => e
            error_msg = e.message
            is_network_error = error_msg.include?('ConnectionFailed') || 
                               error_msg.include?('No route to host') ||
                               error_msg.include?('Timeout') ||
                               error_msg.include?('ECONNREFUSED') ||
                               error_msg.include?('EHOSTUNREACH')
            
            if is_network_error && populate_retry_count < max_populate_retries - 1
              populate_retry_count += 1
              wait_time = populate_retry_count * 2
              puts "  ⚠ Network exception (retry #{populate_retry_count}/#{max_populate_retries}): #{error_msg[0..100]}"
              puts "  → Waiting #{wait_time}s before retry..."
              sleep wait_time
              next
            else
              stats[:errors] << { chapter: chapter, verse: verse, error: "Population exception: #{e.message}", type: 'population' }
              puts "  ✗ Population exception: #{e.message}"
              break
            end
          end
        end
      end
      
      # Step 2: Validate (only if content was populated or already exists)
      text_content.reload
      if text_content.content_populated? && text_content.content.present?
        validate_success = false
        max_validate_retries = 3
        validate_retry_count = 0
        
        begin
          while validate_retry_count < max_validate_retries && !validate_success
            begin
              validation_service = TextContentValidationService.new(text_content)
              validation_result = validation_service.validate_content
              
              if validation_result[:status] == 'success'
                validate_success = true
                stats[:validated] += 1
                is_accurate = validation_result[:is_accurate]
                has_violations = validation_result[:lsv_rule_violations]&.any?
                
                if is_accurate && !has_violations
                  stats[:validation_passed] += 1
                  puts "  ✓ Validation passed (100% accurate, no LSV violations)"
                elsif has_violations
                  stats[:validation_failed] += 1
                  stats[:lsv_violations] += validation_result[:lsv_rule_violations].count
                  puts "  ⚠ Validation: Characters accurate but #{validation_result[:lsv_rule_violations].count} LSV violation(s)"
                  validation_result[:lsv_rule_violations].each do |violation|
                    puts "    - #{violation['word']}: #{violation['violation_type']}"
                  end
                else
                  stats[:validation_failed] += 1
                  accuracy = validation_result[:accuracy_percentage] || 0
                  puts "  ✗ Validation failed: #{accuracy}% accurate"
                end
              else
                # Check if it's a retryable network error
                error_msg = validation_result[:error] || ''
                is_network_error = error_msg.include?('ConnectionFailed') || 
                                   error_msg.include?('No route to host') ||
                                   error_msg.include?('Timeout') ||
                                   error_msg.include?('ECONNREFUSED') ||
                                   error_msg.include?('EHOSTUNREACH')
                
                if is_network_error && validate_retry_count < max_validate_retries - 1
                  validate_retry_count += 1
                  wait_time = validate_retry_count * 2
                  puts "  ⚠ Validation network error (retry #{validate_retry_count}/#{max_validate_retries}): #{error_msg[0..100]}"
                  puts "  → Waiting #{wait_time}s before retry..."
                  sleep wait_time
                  next
                else
                  stats[:errors] << { chapter: chapter, verse: verse, error: "Validation failed: #{validation_result[:error]}", type: 'validation' }
                  puts "  ✗ Validation error: #{validation_result[:error]}"
                  break
                end
              end
            rescue => e
              error_msg = e.message
              is_network_error = error_msg.include?('ConnectionFailed') || 
                                 error_msg.include?('No route to host') ||
                                 error_msg.include?('Timeout') ||
                                 error_msg.include?('ECONNREFUSED') ||
                                 error_msg.include?('EHOSTUNREACH')
              
              if is_network_error && validate_retry_count < max_validate_retries - 1
                validate_retry_count += 1
                wait_time = validate_retry_count * 2
                puts "  ⚠ Validation network exception (retry #{validate_retry_count}/#{max_validate_retries}): #{error_msg[0..100]}"
                puts "  → Waiting #{wait_time}s before retry..."
                sleep wait_time
                next
              else
                stats[:errors] << { chapter: chapter, verse: verse, error: "Validation exception: #{e.message}", type: 'validation' }
                puts "  ✗ Validation exception: #{e.message}"
                break
              end
            end
          end
        end
      else
        puts "  → Skipped validation (content not populated)"
      end
      
      puts ""
      
      # Small delay to avoid overwhelming the API
      sleep 0.5 if index < existing_records.count - 1
    end
    
    # Final summary
    puts ""
    puts "=" * 80
    puts "SUMMARY"
    puts "=" * 80
    puts ""
    puts "Total records processed: #{stats[:total]}"
    puts ""
    puts "Population:"
    puts "  - Already populated (skipped): #{stats[:already_populated]}"
    puts "  - Newly populated: #{stats[:populated]}"
    puts "  - Overwritten: #{stats[:overwritten]}"
    puts ""
    puts "Validation:"
    puts "  - Validated: #{stats[:validated]}"
    puts "  - Passed (100% accurate, no violations): #{stats[:validation_passed]}"
    puts "  - Failed: #{stats[:validation_failed]}"
    puts "  - LSV rule violations found: #{stats[:lsv_violations]}"
    puts ""
    
    if stats[:errors].any?
      network_errors = stats[:errors].select { |e| e[:error].to_s.include?('ConnectionFailed') || e[:error].to_s.include?('No route to host') }
      other_errors = stats[:errors] - network_errors
      
      puts "Errors encountered: #{stats[:errors].count}"
      puts "  - Network errors: #{network_errors.count} (can be retried)"
      puts "  - Other errors: #{other_errors.count}"
      puts ""
      
      if network_errors.any?
        puts "Network errors (retry these):"
        network_errors.first(10).each do |error|
          puts "  - #{book.std_name} #{error[:chapter]}:#{error[:verse]} (#{error[:type]}): #{error[:error][0..80]}"
        end
        if network_errors.count > 10
          puts "  ... and #{network_errors.count - 10} more network errors"
        end
        puts ""
        puts "To retry only failed verses, run:"
        puts "  rake 'text_content:retry_failed_john[#{source_id}]'"
        puts ""
      end
      
      if other_errors.any?
        puts "Other errors:"
        other_errors.first(10).each do |error|
          puts "  - #{book.std_name} #{error[:chapter]}:#{error[:verse]} (#{error[:type]}): #{error[:error][0..80]}"
        end
        if other_errors.count > 10
          puts "  ... and #{other_errors.count - 10} more errors"
        end
        puts ""
      end
    end
    
    if missing_verses.any?
      puts "⚠ Missing verses: #{missing_verses.count} verse(s) need to be created"
      puts ""
    end
    
    # Check for verses that need attention
    needs_attention = stats[:validation_failed] + stats[:lsv_violations]
    if needs_attention > 0
      puts "⚠ #{needs_attention} verse(s) need attention (validation failed or LSV violations)"
      puts ""
    end
    
    if stats[:errors].empty? && missing_verses.empty? && needs_attention == 0
      puts "✓ All verses processed successfully!"
    end
    
    puts ""
    puts "Done!"
  end
  
  desc "Retry failed verses for John. Usage: rake 'text_content:retry_failed_john[source_id]'"
  task :retry_failed_john, [:source_id] => :environment do |t, args|
    source_id = args[:source_id] || "1"
    force = true # Always force retry for failed verses
    
    puts "=" * 80
    puts "Retrying Failed John Verses"
    puts "Source ID: #{source_id}"
    puts "=" * 80
    puts ""
    
    # Find source
    source = Source.unscoped.find_by(id: source_id.to_i)
    unless source
      puts "✗ Source not found: #{source_id}"
      exit 1
    end
    
    # Find John book
    book = Book.unscoped.find_by(code: 'JHN') || Book.unscoped.find_by(code: 'JOH')
    unless book
      puts "✗ Book 'John' not found"
      exit 1
    end
    
    # Find verses that need attention:
    # 1. Not populated
    # 2. Not validated
    # 3. Validation failed
    # 4. Has LSV violations
    
    not_populated = TextContent.unscoped.where(
      source_id: source.id,
      book_id: book.id
    ).where("content_populated_at IS NULL OR content IS NULL OR content = ''")
    
    not_validated = TextContent.unscoped.where(
      source_id: source.id,
      book_id: book.id
    ).where("content_populated_at IS NOT NULL AND content IS NOT NULL AND content != ''")
    .where("content_validated_at IS NULL")
    
    validation_failed = TextContent.unscoped.where(
      source_id: source.id,
      book_id: book.id
    ).where("content_validation_result->>'is_accurate' = 'false'")
    
    has_violations = TextContent.unscoped.where(
      source_id: source.id,
      book_id: book.id
    ).where("jsonb_array_length(COALESCE(content_validation_result->'lsv_rule_violations', '[]'::jsonb)) > 0")
    
    # Combine all verses that need retry
    all_failed_ids = (not_populated.pluck(:id) + 
                      not_validated.pluck(:id) + 
                      validation_failed.pluck(:id) + 
                      has_violations.pluck(:id)).uniq
    
    failed_records = TextContent.unscoped.where(id: all_failed_ids).order(:unit_group, :unit)
    
    puts "Found #{failed_records.count} verse(s) that need retry:"
    puts "  - Not populated: #{not_populated.count}"
    puts "  - Not validated: #{not_validated.count}"
    puts "  - Validation failed: #{validation_failed.count}"
    puts "  - Has LSV violations: #{has_violations.count}"
    puts ""
    
    if failed_records.empty?
      puts "✓ No verses need retry!"
      exit 0
    end
    
    stats = {
      populated: 0,
      validated: 0,
      validation_passed: 0,
      validation_failed: 0,
      errors: []
    }
    
    puts "=" * 80
    puts "Retrying failed verses..."
    puts "=" * 80
    puts ""
    
    failed_records.each_with_index do |text_content, index|
      chapter = text_content.unit_group
      verse = text_content.unit
      progress = "[#{index + 1}/#{failed_records.count}]"
      
      puts "#{progress} Retrying: #{book.std_name} #{chapter}:#{verse} (#{text_content.unit_key})"
      
      # Populate if needed
      unless text_content.content_populated? && text_content.content.present?
        begin
          population_service = TextContentPopulationService.new(text_content)
          population_result = population_service.populate_content_fields(force: force)
          
          if population_result[:status] == 'success'
            stats[:populated] += 1
            puts "  ✓ Populated"
          else
            stats[:errors] << { chapter: chapter, verse: verse, error: population_result[:error] }
            puts "  ✗ Population failed: #{population_result[:error]}"
            next
          end
        rescue => e
          stats[:errors] << { chapter: chapter, verse: verse, error: "Population exception: #{e.message}" }
          puts "  ✗ Population exception: #{e.message}"
          next
        end
      end
      
      # Validate
      text_content.reload
      if text_content.content_populated? && text_content.content.present?
        begin
          validation_service = TextContentValidationService.new(text_content)
          validation_result = validation_service.validate_content
          
          if validation_result[:status] == 'success'
            stats[:validated] += 1
            is_accurate = validation_result[:is_accurate]
            has_violations = validation_result[:lsv_rule_violations]&.any?
            
            if is_accurate && !has_violations
              stats[:validation_passed] += 1
              puts "  ✓ Validation passed"
            else
              stats[:validation_failed] += 1
              if has_violations
                puts "  ⚠ Validation: #{validation_result[:lsv_rule_violations].count} LSV violation(s)"
              else
                puts "  ✗ Validation failed: #{validation_result[:accuracy_percentage]}% accurate"
              end
            end
          else
            stats[:errors] << { chapter: chapter, verse: verse, error: "Validation failed: #{validation_result[:error]}" }
            puts "  ✗ Validation error: #{validation_result[:error]}"
          end
        rescue => e
          stats[:errors] << { chapter: chapter, verse: verse, error: "Validation exception: #{e.message}" }
          puts "  ✗ Validation exception: #{e.message}"
        end
      end
      
      puts ""
      sleep 0.5 if index < failed_records.count - 1
    end
    
    puts ""
    puts "=" * 80
    puts "RETRY SUMMARY"
    puts "=" * 80
    puts ""
    puts "Verses retried: #{failed_records.count}"
    puts "  - Populated: #{stats[:populated]}"
    puts "  - Validated: #{stats[:validated]}"
    puts "  - Validation passed: #{stats[:validation_passed]}"
    puts "  - Still failed: #{stats[:validation_failed]}"
    puts ""
    
    if stats[:errors].any?
      puts "Errors: #{stats[:errors].count}"
      stats[:errors].first(5).each do |error|
        puts "  - #{book.std_name} #{error[:chapter]}:#{error[:verse]}: #{error[:error][0..80]}"
      end
    end
    
    puts ""
    puts "Done!"
  end
end

