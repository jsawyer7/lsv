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
  
  desc "Populate and validate content for a specific chapter (e.g., John chapter 1). Usage: rake 'text_content:populate_chapter[source_id,book_code,chapter]' or use FORCE=true to overwrite existing content"
  task :populate_chapter, [:source_id, :book_code, :chapter] => :environment do |t, args|
    source_id = args[:source_id] || "10"
    book_code = args[:book_code] || "JHN"
    chapter = args[:chapter]&.to_i
    
    unless chapter
      puts "Usage: rake 'text_content:populate_chapter[source_id,book_code,chapter]'"
      puts "Example: rake 'text_content:populate_chapter[10,JHN,1]'"
      exit 1
    end
    
    force = ENV['FORCE'] == 'true'
    
    puts "=" * 80
    puts "Populate and Validate Chapter"
    puts "Source ID: #{source_id}"
    puts "Book: #{book_code}"
    puts "Chapter: #{chapter}"
    puts "Force: #{force ? 'YES (will overwrite existing)' : 'NO (will skip existing)'}"
    puts "=" * 80
    puts ""
    
    # Find source
    source = Source.unscoped.find_by(id: source_id.to_i)
    unless source
      puts "✗ Source not found: #{source_id}"
      exit 1
    end
    
    # Find book
    book = Book.unscoped.find_by(code: book_code) || Book.unscoped.where('LOWER(code) = LOWER(?)', book_code).first
    unless book
      puts "✗ Book not found: #{book_code}"
      exit 1
    end
    
    # Get expected verse count for this chapter
    expected_verses = VerseCountReference.expected_verses(book.code, chapter)
    
    if expected_verses.nil?
      puts "⚠ Warning: No verse count reference found for #{book.std_name} chapter #{chapter}"
      puts "  Will process all existing records for this chapter"
    else
      puts "Expected verses in #{book.std_name} chapter #{chapter}: #{expected_verses}"
      puts ""
    end
    
    # Find all existing records for this chapter
    existing_records = TextContent.unscoped.where(
      source_id: source.id,
      book_id: book.id,
      unit_group: chapter
    ).order(:unit)
    
    if existing_records.empty?
      puts "✗ No text content records found for #{book.std_name} chapter #{chapter}"
      puts "  Please create the records first using: rake 'text_content:create_all[#{source_id},#{book_code}]'"
      exit 1
    end
    
    puts "Found #{existing_records.count} record(s) for #{book.std_name} chapter #{chapter}"
    puts ""
    
    # Check for missing verses
    missing_verses = []
    if expected_verses
      existing_verse_numbers = existing_records.pluck(:unit).compact.sort
      expected_verse_numbers = (1..expected_verses).to_a
      missing_verses = expected_verse_numbers - existing_verse_numbers
      
      if missing_verses.any?
        puts "⚠ Missing verses: #{missing_verses.join(', ')}"
        puts "  These verses need to be created first"
        puts ""
      end
    end
    
    # Stats tracking
    stats = {
      total: existing_records.count,
      already_populated: 0,
      populated: 0,
      overwritten: 0,
      validated: 0,
      validation_passed: 0,
      validation_failed: 0,
      lsv_violations: 0,
      errors: []
    }
    
    # Process each verse
    existing_records.each_with_index do |text_content, index|
      verse = text_content.unit
      puts "[#{index + 1}/#{existing_records.count}] Processing: #{book.std_name} #{chapter}:#{verse} (#{text_content.unit_key})"
      
      # Step 1: Populate
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
                puts "  ✓ Content populated (overwritten)"
              else
                stats[:populated] += 1
                puts "  ✓ Content populated"
              end
            elsif population_result[:status] == 'already_populated' && !force
              stats[:already_populated] += 1
              populate_success = true
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
                puts "  ⚠ Population network error (retry #{populate_retry_count}/#{max_populate_retries}): #{error_msg[0..100]}"
                puts "  → Waiting #{wait_time}s before retry..."
                sleep wait_time
                next
              else
                stats[:errors] << { chapter: chapter, verse: verse, error: "Population failed: #{population_result[:error]}", type: 'population' }
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
              puts "  ⚠ Population network exception (retry #{populate_retry_count}/#{max_populate_retries}): #{error_msg[0..100]}"
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
                  validation_result[:lsv_rule_violations].first(3).each do |violation|
                    puts "    - #{violation['token'] || violation['word']}: #{violation['violation_type']}"
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
      puts "⚠ Missing verses: #{missing_verses.join(', ')}"
      puts "  These verses need to be created first"
      puts ""
    end
    
    # Check for verses that need attention
    needs_attention = stats[:validation_failed] + stats[:lsv_violations]
    if needs_attention > 0
      puts "⚠ #{needs_attention} verse(s) need attention (validation failed or LSV violations)"
      puts ""
    end
    
    if stats[:errors].empty? && missing_verses.empty? && needs_attention == 0
      puts "✓ All verses in chapter #{chapter} processed successfully!"
    end
    
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
  
  desc "Clear all content fields for John (or all text contents) to start fresh. Usage: rake 'text_content:clear_content[source_id,book_code]' or use ALL=true to clear all sources. Use DRY_RUN=false to actually clear (default: DRY_RUN=true)"
  task :clear_content, [:source_id, :book_code] => :environment do |t, args|
    source_id = args[:source_id]
    book_code = args[:book_code]
    clear_all = ENV['ALL'] == 'true'
    dry_run = ENV['DRY_RUN'] != 'false'  # Default to dry run for safety
    
    puts "=" * 80
    puts "Clearing Content Fields"
    puts "Mode: #{dry_run ? 'DRY RUN (no changes)' : 'LIVE (will clear content)'}"
    puts "=" * 80
    puts ""
    
    if clear_all
      puts "⚠ Clearing ALL text contents (all sources, all books)"
      text_contents = TextContent.unscoped.all
    elsif source_id && book_code
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
      
      puts "Source: #{source.name} (ID: #{source.id})"
      puts "Book: #{book.std_name} (#{book.code})"
      text_contents = TextContent.unscoped.where(source_id: source.id, book_id: book.id)
    else
      puts "Usage:"
      puts "  Clear specific source/book: rake 'text_content:clear_content[source_id,book_code]'"
      puts "  Clear ALL text contents: ALL=true rake 'text_content:clear_content'"
      puts ""
      puts "To actually clear (not dry run): DRY_RUN=false rake 'text_content:clear_content[...]'"
      exit 1
    end
    
    total_count = text_contents.count
    populated_count = text_contents.where.not(content_populated_at: nil).count
    validated_count = text_contents.where.not(content_validated_at: nil).count
    
    puts ""
    puts "Found #{total_count} text content record(s)"
    puts "  - With populated content: #{populated_count}"
    puts "  - With validation: #{validated_count}"
    puts ""
    
    if total_count == 0
      puts "✓ No records to clear"
      exit 0
    end
    
    if dry_run
      puts "DRY RUN MODE: No records will be cleared."
      puts ""
      puts "Records that would be cleared:"
      text_contents.limit(10).each do |tc|
        has_content = tc.content.present? || tc.word_for_word_translation.present? || tc.lsv_literal_reconstruction.present?
        puts "  - #{tc.unit_key}: #{has_content ? 'Has content' : 'Empty'}"
      end
      if total_count > 10
        puts "  ... and #{total_count - 10} more records"
      end
      puts ""
      puts "To actually clear these records, run:"
      if clear_all
        puts "  DRY_RUN=false ALL=true rake 'text_content:clear_content'"
      else
        puts "  DRY_RUN=false rake 'text_content:clear_content[#{source_id},#{book_code}]'"
      end
    else
      puts "LIVE MODE: Clearing content fields..."
      puts ""
      
      cleared_count = 0
      errors = []
      
      text_contents.find_each do |text_content|
        begin
          # Clear all content-related fields
          text_content.update!(
            content: '',
            word_for_word_translation: [],
            lsv_literal_reconstruction: nil,
            content_populated_at: nil,
            content_populated_by: nil,
            content_validated_at: nil,
            content_validated_by: nil,
            content_validation_result: nil,
            validation_notes: nil
          )
          cleared_count += 1
          
          if cleared_count % 50 == 0
            puts "  Cleared #{cleared_count}/#{total_count} records..."
          end
        rescue => e
          errors << { unit_key: text_content.unit_key, error: e.message }
          Rails.logger.error "Failed to clear #{text_content.unit_key}: #{e.message}"
        end
      end
      
      puts ""
      puts "=" * 80
      puts "SUMMARY"
      puts "=" * 80
      puts ""
      puts "Total records: #{total_count}"
      puts "Successfully cleared: #{cleared_count}"
      puts "Errors: #{errors.count}"
      
      if errors.any?
        puts ""
        puts "Errors encountered:"
        errors.first(10).each do |error|
          puts "  - #{error[:unit_key]}: #{error[:error]}"
        end
        if errors.count > 10
          puts "  ... and #{errors.count - 10} more errors"
        end
      end
    end
    
    puts ""
    puts "Done!"
  end

  desc "Delete content for specific verses by unit_key. Usage: rake 'text_content:delete_verse_content' or use DRY_RUN=false to actually delete (default: DRY_RUN=true)"
  task :delete_verse_content => :environment do
    dry_run = ENV['DRY_RUN'] != 'false'  # Default to dry run for safety
    
    # List of verses to delete content for (unit_keys)
    verses_to_delete = [
      'GRK_WH1881|MAT|17|21',
      'GRK_WH1881|MAT|18|11',
      'GRK_WH1881|MAT|23|14',
      'GRK_WH1881|MRK|7|16',
      'GRK_WH1881|MRK|9|44',
      'GRK_WH1881|MRK|9|46',
      'GRK_WH1881|MRK|11|26',
      'GRK_WH1881|MRK|15|28',
      'GRK_WH1881|LUK|17|36',
      'GRK_WH1881|LUK|23|17',
      'GRK_WH1881|JHN|5|4',
      'GRK_WH1881|ACT|8|37',
      'GRK_WH1881|ACT|15|34',
      'GRK_WH1881|ACT|24|7',
      'GRK_WH1881|ACT|28|29',
      'GRK_WH1881|ROM|16|24',
      'GRK_WH1881|LUK|24|12'
    ]
    
    puts "=" * 80
    puts "Deleting Content for Specific Verses"
    puts "Mode: #{dry_run ? 'DRY RUN (no changes)' : 'LIVE (will delete content)'}"
    puts "=" * 80
    puts ""
    puts "Total verses to process: #{verses_to_delete.count}"
    puts ""
    
    # Find all text contents by unit_key
    text_contents = TextContent.unscoped.where(unit_key: verses_to_delete)
    found_count = text_contents.count
    not_found = verses_to_delete - text_contents.pluck(:unit_key)
    
    puts "Found #{found_count} text content record(s) matching the unit_keys"
    if not_found.any?
      puts "⚠ Not found (#{not_found.count}):"
      not_found.each { |uk| puts "  - #{uk}" }
    end
    puts ""
    
    if found_count == 0
      puts "✓ No records found to delete content for"
      exit 0
    end
    
    # Show what will be deleted
    puts "Verses that will have content deleted:"
    text_contents.each do |tc|
      has_content = tc.content.present? || tc.word_for_word_translation.present? || tc.lsv_literal_reconstruction.present?
      puts "  - #{tc.unit_key}: #{has_content ? 'Has content' : 'Already empty'}"
    end
    puts ""
    
    if dry_run
      puts "DRY RUN MODE: No records will be modified."
      puts ""
      puts "To actually delete content for these records, run:"
      puts "  DRY_RUN=false rake 'text_content:delete_verse_content'"
    else
      puts "LIVE MODE: Deleting content fields..."
      puts ""
      
      deleted_count = 0
      errors = []
      
      text_contents.find_each do |text_content|
        begin
          # Clear all content-related fields
          text_content.update!(
            content: '',
            word_for_word_translation: [],
            lsv_literal_reconstruction: nil,
            content_populated_at: nil,
            content_populated_by: nil,
            content_validated_at: nil,
            content_validated_by: nil,
            content_validation_result: nil,
            validation_notes: nil
          )
          deleted_count += 1
          puts "  ✓ Deleted content for: #{text_content.unit_key}"
        rescue => e
          errors << { unit_key: text_content.unit_key, error: e.message }
          Rails.logger.error "Failed to delete content for #{text_content.unit_key}: #{e.message}"
          puts "  ✗ Error deleting content for #{text_content.unit_key}: #{e.message}"
        end
      end
      
      puts ""
      puts "=" * 80
      puts "SUMMARY"
      puts "=" * 80
      puts ""
      puts "Total records found: #{found_count}"
      puts "Successfully deleted content: #{deleted_count}"
      puts "Errors: #{errors.count}"
      
      if errors.any?
        puts ""
        puts "Errors encountered:"
        errors.each do |error|
          puts "  - #{error[:unit_key]}: #{error[:error]}"
        end
      end
      
      if not_found.any?
        puts ""
        puts "⚠ Note: #{not_found.count} verse(s) were not found in the database:"
        not_found.each { |uk| puts "  - #{uk}" }
      end
    end
    
    puts ""
    puts "Done!"
  end

  desc "Fix book codes: Ensure JUD is Jude and create Judges with code JUG. Usage: rake 'text_content:fix_jud_judges' or use DRY_RUN=false to actually make changes (default: DRY_RUN=true)"
  task :fix_jud_judges => :environment do
    dry_run = ENV['DRY_RUN'] != 'false'  # Default to dry run for safety
    
    puts "=" * 80
    puts "Fixing Book Codes: JUD -> Jude, Creating Judges (JUG)"
    puts "Mode: #{dry_run ? 'DRY RUN (no changes)' : 'LIVE (will make changes)'}"
    puts "=" * 80
    puts ""
    
    # Step 1: Find or update JUD book to be Jude
    puts "Step 1: Ensuring JUD is Jude"
    puts "-" * 80
    
    jud_book = Book.unscoped.find_by(code: 'JUD')
    
    if jud_book
      puts "✓ Found book with code JUD:"
      puts "  - ID: #{jud_book.id}"
      puts "  - Code: #{jud_book.code}"
      puts "  - Name: #{jud_book.std_name}"
      puts "  - Description: #{jud_book.description || 'N/A'}"
      puts ""
      
      if jud_book.std_name != 'Jude'
        puts "⚠ Book name is '#{jud_book.std_name}', should be 'Jude'"
        if dry_run
          puts "  → Would update std_name to 'Jude'"
        else
          jud_book.update!(std_name: 'Jude')
          puts "  ✓ Updated std_name to 'Jude'"
        end
      else
        puts "✓ Book name is already 'Jude' (correct)"
      end
      
      # Check for any text_contents using this book
      text_content_count = TextContent.unscoped.where(book_id: jud_book.id).count
      if text_content_count > 0
        puts "  ⚠ Found #{text_content_count} text_content record(s) using this book"
        puts "    These records will continue to reference JUD (Jude) - no changes needed"
      end
    else
      puts "⚠ Book with code JUD not found"
      if dry_run
        puts "  → Would create new book: code='JUD', std_name='Jude'"
      else
        jud_book = Book.create!(
          code: 'JUD',
          std_name: 'Jude',
          description: 'Epistle of Jude'
        )
        puts "  ✓ Created new book: JUD (Jude)"
      end
    end
    
    puts ""
    
    # Step 2: Create Judges book with code JUG
    puts "Step 2: Creating Judges book with code JUG"
    puts "-" * 80
    
    jug_book = Book.unscoped.find_by(code: 'JUG')
    
    if jug_book
      puts "⚠ Book with code JUG already exists:"
      puts "  - ID: #{jug_book.id}"
      puts "  - Code: #{jug_book.code}"
      puts "  - Name: #{jug_book.std_name}"
      puts "  - Description: #{jug_book.description || 'N/A'}"
      puts ""
      
      if jug_book.std_name != 'Judges'
        puts "⚠ Book name is '#{jug_book.std_name}', should be 'Judges'"
        if dry_run
          puts "  → Would update std_name to 'Judges'"
        else
          jug_book.update!(std_name: 'Judges')
          puts "  ✓ Updated std_name to 'Judges'"
        end
      else
        puts "✓ Book name is already 'Judges' (correct)"
      end
      
      # Check for any text_contents using this book
      text_content_count = TextContent.unscoped.where(book_id: jug_book.id).count
      if text_content_count > 0
        puts "  ℹ Found #{text_content_count} text_content record(s) using this book"
      end
    else
      puts "Book with code JUG not found"
      if dry_run
        puts "  → Would create new book: code='JUG', std_name='Judges'"
      else
        jug_book = Book.create!(
          code: 'JUG',
          std_name: 'Judges',
          description: 'Book of Judges'
        )
        puts "  ✓ Created new book: JUG (Judges)"
      end
    end
    
    puts ""
    
    # Step 3: Summary
    puts "=" * 80
    puts "SUMMARY"
    puts "=" * 80
    puts ""
    
    if dry_run
      puts "DRY RUN MODE: No changes were made."
      puts ""
      puts "To actually make these changes, run:"
      puts "  DRY_RUN=false rake 'text_content:fix_jud_judges'"
    else
      puts "LIVE MODE: Changes completed."
      puts ""
      puts "Final status:"
      
      final_jud = Book.unscoped.find_by(code: 'JUD')
      final_jug = Book.unscoped.find_by(code: 'JUG')
      
      if final_jud
        puts "  ✓ JUD: #{final_jud.std_name} (ID: #{final_jud.id})"
      else
        puts "  ✗ JUD: Not found"
      end
      
      if final_jug
        puts "  ✓ JUG: #{final_jug.std_name} (ID: #{final_jug.id})"
      else
        puts "  ✗ JUG: Not found"
      end
      
      puts ""
      puts "Note: If you need to add verse count data for Judges (JUG),"
      puts "      update app/services/verse_count_reference.rb to include"
      puts "      Old Testament verse counts or add JUG to the reference data."
    end
    
    puts ""
    puts "Done!"
  end

  # ============================================================================
  # PRODUCTION BATCH PROCESSING TASKS (Concurrent Processing)
  # ============================================================================
end

namespace :lexical do
    desc "Populate entire book with concurrent processing. Usage: rake 'lexical:populate_book[source_id,book_code]' or FORCE=true"
    task :populate_book, [:source_id, :book_code] => :environment do |t, args|
      source_id = args[:source_id] || "10"
      book_code = args[:book_code] || "JHN"
      force = ENV['FORCE'] == 'true'
      batch_size = ENV.fetch('BATCH_SIZE', '7').to_i
      max_concurrent = ENV.fetch('GROK_MAX_CONCURRENT', '30').to_i
      model = ENV.fetch('GROK_MODEL', 'grok-4-0709')

      puts "=" * 80
      puts "Populating Book with Concurrent Processing"
      puts "Source ID: #{source_id}"
      puts "Book Code: #{book_code}"
      puts "Model: #{model}"
      puts "Max Concurrent: #{max_concurrent}"
      puts "Batch Size: #{batch_size}"
      puts "Force: #{force ? 'YES (will overwrite existing)' : 'NO (skip existing)'}"
      puts "=" * 80
      puts ""

      # Find source
      source = Source.unscoped.find_by(id: source_id.to_i)
      unless source
        puts "✗ Source not found: #{source_id}"
        exit 1
      end

      # Find book
      book = Book.unscoped.find_by(code: book_code) || Book.unscoped.where('LOWER(code) = LOWER(?)', book_code).first
      unless book
        puts "✗ Book not found: #{book_code}"
        exit 1
      end

      puts "✓ Source: #{source.name} (ID: #{source.id})"
      puts "✓ Book: #{book.std_name} (#{book.code})"
      puts ""

      # Get scope of verses to process
      scope = TextContent.unscoped.where(source_id: source.id, book_id: book.id)
      
      unless force
        # Skip already successfully populated
        scope = scope.where.not(population_status: 'success')
      end

      total = scope.count
      
      if total == 0
        puts "✓ No verses to process (all already populated)"
        exit 0
      end

      puts "Found #{total} verse(s) to process"
      puts ""

      # Process in batches using concurrent futures
      require 'concurrent'
      
      processed = 0
      success_count = 0
      error_count = 0
      start_time = Time.current

      scope.find_in_batches(batch_size: batch_size) do |batch|
        puts "Processing batch of #{batch.size} verses (#{processed + 1} to #{processed + batch.size} of #{total})..."
        
        # Create concurrent futures for this batch
        futures = batch.map do |tc|
          Concurrent::Future.execute do
            begin
              service = TextContentPopulationService.new(tc)
              result = service.populate_content_fields(force: force)
              # Ensure result is always a hash with status
              result.is_a?(Hash) ? result : { status: 'error', error: 'Invalid result format' }
            rescue => e
              # Ensure we always return a hash with status
              { status: 'error', error: "#{e.class.name}: #{e.message}" }
            end
          end
        end

        # Wait for all futures in this batch to complete
        results = futures.map do |future|
          begin
            result = future.value
            # Ensure result is always a hash with status
            result.is_a?(Hash) ? result : { status: 'error', error: 'Future returned nil or invalid result' }
          rescue => e
            # Handle exceptions from futures
            { status: 'error', error: "#{e.class.name}: #{e.message}" }
          end
        end
        
        # Count successes and errors
        batch_success = results.count { |r| r && r.is_a?(Hash) && r[:status] == 'success' }
        batch_errors = results.count { |r| r && r.is_a?(Hash) && r[:status] == 'error' }
        
        success_count += batch_success
        error_count += batch_errors
        processed += batch.size

        # Progress bar
        progress = (processed.to_f / total * 100).round(1)
        bar_length = 50
        filled = (progress / 100.0 * bar_length).floor
        bar = '█' * filled + '░' * (bar_length - filled)
        
        puts "  Batch complete | #{processed}/#{total} (#{progress}%) | Success: #{batch_success}/#{batch.size} | Errors: #{batch_errors} | [#{bar}]"
        puts ""
      end

      elapsed = Time.current - start_time
      elapsed_minutes = (elapsed / 60.0).round(2)

      puts "=" * 80
      puts "Processing Complete"
      puts "=" * 80
      puts "Total processed: #{processed}"
      puts "  - Success: #{success_count}"
      puts "  - Errors: #{error_count}"
      puts "  - Already populated: #{processed - success_count - error_count}"
      puts "Time elapsed: #{elapsed_minutes} minutes"
      puts "Average: #{(elapsed / processed).round(2)} seconds per verse" if processed > 0
      puts ""

      # Show error summary if any
      if error_count > 0
        error_records = scope.where(population_status: 'error').limit(10)
        if error_records.any?
          puts "Sample errors:"
          error_records.each do |tc|
            puts "  - #{tc.unit_key}: #{tc.population_error_message&.truncate(80)}"
          end
          puts ""
        end
        puts "⚠ Run with FORCE=true to retry errors, or check individual records"
      end

      puts "Done!"
    end

    desc "Populate entire source (all books) with concurrent processing. Usage: rake 'lexical:populate_source[source_id]' or FORCE=true"
    task :populate_source, [:source_id] => :environment do |t, args|
      source_id = args[:source_id] || "10"
      force = ENV['FORCE'] == 'true'
      batch_size = ENV.fetch('BATCH_SIZE', '7').to_i

      puts "=" * 80
      puts "Populating Entire Source with Concurrent Processing"
      puts "Source ID: #{source_id}"
      puts "Force: #{force ? 'YES (will overwrite existing)' : 'NO (skip existing)'}"
      puts "=" * 80
      puts ""

      # Find source
      source = Source.unscoped.find_by(id: source_id.to_i)
      unless source
        puts "✗ Source not found: #{source_id}"
        exit 1
      end

      puts "✓ Source: #{source.name} (ID: #{source.id})"
      puts ""

      # Get all books for this source
      books = Book.unscoped.joins(:text_contents)
        .where(text_contents: { source_id: source.id })
        .distinct
        .order(:code)

      if books.empty?
        puts "✗ No books found for source #{source.name}"
        exit 1
      end

      puts "Found #{books.count} book(s) to process:"
      books.each { |b| puts "  - #{b.std_name} (#{b.code})" }
      puts ""

      total_processed = 0
      total_success = 0
      total_errors = 0
      start_time = Time.current

      books.each_with_index do |book, index|
        puts "=" * 80
        puts "[#{index + 1}/#{books.count}] Processing: #{book.std_name} (#{book.code})"
        puts "=" * 80
        puts ""

        # Get scope for this book
        scope = TextContent.unscoped.where(source_id: source.id, book_id: book.id)
        
        unless force
          scope = scope.where.not(population_status: 'success')
        end

        book_total = scope.count

        if book_total == 0
          puts "✓ No verses to process for #{book.std_name} (all already populated)"
          puts ""
          next
        end

        puts "Processing #{book_total} verse(s) for #{book.std_name}..."
        puts ""

        # Process in batches
        book_processed = 0
        book_success = 0
        book_errors = 0

        scope.find_in_batches(batch_size: batch_size) do |batch|
          futures = batch.map do |tc|
            Concurrent::Future.execute do
              begin
                service = TextContentPopulationService.new(tc)
                result = service.populate_content_fields(force: force)
                result.is_a?(Hash) ? result : { status: 'error', error: 'Invalid result format' }
              rescue => e
                { status: 'error', error: "#{e.class.name}: #{e.message}" }
              end
            end
          end

          results = futures.map do |future|
            begin
              result = future.value
              result.is_a?(Hash) ? result : { status: 'error', error: 'Future returned nil or invalid result' }
            rescue => e
              { status: 'error', error: "#{e.class.name}: #{e.message}" }
            end
          end
          
          batch_success = results.count { |r| r && r.is_a?(Hash) && r[:status] == 'success' }
          batch_errors = results.count { |r| r && r.is_a?(Hash) && r[:status] == 'error' }
          
          book_success += batch_success
          book_errors += batch_errors
          book_processed += batch.size

          progress = (book_processed.to_f / book_total * 100).round(1)
          puts "  #{book.std_name}: #{book_processed}/#{book_total} (#{progress}%) | Success: #{book_success} | Errors: #{book_errors}"
        end

        total_processed += book_processed
        total_success += book_success
        total_errors += book_errors

        puts ""
        puts "✓ #{book.std_name} complete: #{book_success} success, #{book_errors} errors"
        puts ""
      end

      elapsed = Time.current - start_time
      elapsed_minutes = (elapsed / 60.0).round(2)

      puts "=" * 80
      puts "Source Processing Complete"
      puts "=" * 80
      puts "Total processed: #{total_processed}"
      puts "  - Success: #{total_success}"
      puts "  - Errors: #{total_errors}"
      puts "Time elapsed: #{elapsed_minutes} minutes"
      puts "Average: #{(elapsed / total_processed).round(2)} seconds per verse" if total_processed > 0
      puts ""

      if total_errors > 0
        puts "⚠ #{total_errors} error(s) encountered. Run with FORCE=true to retry, or check individual records"
      end

      puts "Done!"
    end

    desc "Resume processing for failed/pending verses. Usage: rake 'lexical:resume[source_id]' or specify book_code"
    task :resume, [:source_id, :book_code] => :environment do |t, args|
      source_id = args[:source_id] || "10"
      book_code = args[:book_code]
      batch_size = ENV.fetch('BATCH_SIZE', '7').to_i

      puts "=" * 80
      puts "Resuming Failed/Pending Verses"
      puts "Source ID: #{source_id}"
      puts "Book Code: #{book_code || 'ALL'}"
      puts "=" * 80
      puts ""

      source = Source.unscoped.find_by(id: source_id.to_i)
      unless source
        puts "✗ Source not found: #{source_id}"
        exit 1
      end

      # Get scope
      scope = TextContent.unscoped.where(source_id: source.id)
      scope = scope.where(book_id: Book.unscoped.find_by(code: book_code).id) if book_code
      
      # Only process pending or error status
      scope = scope.where(population_status: ['pending', 'error'])

      total = scope.count

      if total == 0
        puts "✓ No pending or error verses to resume"
        exit 0
      end

      puts "Found #{total} verse(s) to resume"
      puts ""

      processed = 0
      success_count = 0
      error_count = 0
      start_time = Time.current

        scope.find_in_batches(batch_size: batch_size) do |batch|
          puts "Processing batch of #{batch.size} verses..."
          
          futures = batch.map do |tc|
            Concurrent::Future.execute do
              begin
                service = TextContentPopulationService.new(tc)
                result = service.populate_content_fields(force: true)
                result.is_a?(Hash) ? result : { status: 'error', error: 'Invalid result format' }
              rescue => e
                { status: 'error', error: "#{e.class.name}: #{e.message}" }
              end
            end
          end

          results = futures.map.with_index do |future, idx|
            begin
              if future.wait(300) # Wait up to 5 minutes
                result = future.value
                result.is_a?(Hash) ? result : { status: 'error', error: 'Future returned nil or invalid result' }
              else
                Rails.logger.error "Future #{idx} timed out after 5 minutes"
                { status: 'error', error: 'Request timed out after 5 minutes' }
              end
            rescue => e
              Rails.logger.error "Exception getting future #{idx} value: #{e.class.name}: #{e.message}"
              { status: 'error', error: "#{e.class.name}: #{e.message}" }
            end
          end
          
          batch_success = results.count { |r| r && r.is_a?(Hash) && r[:status] == 'success' }
          batch_errors = results.count { |r| r && r.is_a?(Hash) && r[:status] == 'error' }
        
        success_count += batch_success
        error_count += batch_errors
        processed += batch.size

        progress = (processed.to_f / total * 100).round(1)
        puts "  #{processed}/#{total} (#{progress}%) | Success: #{batch_success} | Errors: #{batch_errors}"
      end

      elapsed = Time.current - start_time
      elapsed_minutes = (elapsed / 60.0).round(2)

      puts ""
      puts "Resume Complete"
      puts "  - Processed: #{processed}"
      puts "  - Success: #{success_count}"
      puts "  - Errors: #{error_count}"
      puts "  - Time: #{elapsed_minutes} minutes"
      puts ""
      puts "Done!"
    end

    desc "Show population status summary. Usage: rake 'lexical:status[source_id]'"
    task :status, [:source_id] => :environment do |t, args|
      source_id = args[:source_id] || "10"

      source = Source.unscoped.find_by(id: source_id.to_i)
      unless source
        puts "✗ Source not found: #{source_id}"
        exit 1
      end

      puts "=" * 80
      puts "Population Status Summary"
      puts "Source: #{source.name} (ID: #{source.id})"
      puts "=" * 80
      puts ""

      # Get status counts
      statuses = TextContent.unscoped.where(source_id: source.id)
        .group(:population_status)
        .count

      total = TextContent.unscoped.where(source_id: source.id).count

      puts "Total verses: #{total}"
      puts ""
      puts "Status breakdown:"
      statuses.each do |status, count|
        percentage = total > 0 ? (count.to_f / total * 100).round(1) : 0
        puts "  - #{status || 'NULL'}: #{count} (#{percentage}%)"
      end
      puts ""

      # Show by book
      puts "By book:"
      Book.unscoped.joins(:text_contents)
        .where(text_contents: { source_id: source.id })
        .distinct
        .order(:code)
        .each do |book|
          book_total = TextContent.unscoped.where(source_id: source.id, book_id: book.id).count
          book_success = TextContent.unscoped.where(source_id: source.id, book_id: book.id, population_status: 'success').count
          percentage = book_total > 0 ? (book_success.to_f / book_total * 100).round(1) : 0
          puts "  - #{book.std_name} (#{book.code}): #{book_success}/#{book_total} (#{percentage}%)"
        end
      puts ""
      puts "Done!"
    end

    # ============================================================================
    # AUTOMATED CREATION AND POPULATION FOR WESTCOTT-HORT NEW TESTAMENT
    # ============================================================================

    desc "Create all chapters and verses for Westcott-Hort New Testament, then populate them. Usage: rake 'lexical:create_and_populate_wh_nt[source_id]'"
    task :create_and_populate_wh_nt, [:source_id] => :environment do |t, args|
      source_id = args[:source_id]
      force_create = ENV['FORCE_CREATE'] == 'true'
      force_populate = ENV['FORCE_POPULATE'] == 'true'
      batch_size = ENV.fetch('BATCH_SIZE', '7').to_i
      max_concurrent = ENV.fetch('GROK_MAX_CONCURRENT', '30').to_i
      model = ENV.fetch('GROK_MODEL', 'grok-4-0709')

      puts "=" * 80
      puts "Create and Populate Westcott-Hort New Testament"
      puts "=" * 80
      puts ""

      # Step 1: Find Westcott-Hort source
      source = if source_id
        Source.unscoped.find_by(id: source_id.to_i)
      else
        # Try to find by name variations
        Source.unscoped.where('name ILIKE ? OR name ILIKE ? OR name ILIKE ? OR code ILIKE ?',
                              '%Westcott%', '%Hort%', '%1881%', '%WH%').first
      end

      unless source
        puts "✗ Westcott-Hort source not found"
        puts ""
        puts "Available sources:"
        Source.unscoped.limit(10).each do |s|
          puts "  - ID: #{s.id}, Name: #{s.name}, Code: #{s.code}"
        end
        puts ""
        puts "Usage: rake 'lexical:create_and_populate_wh_nt[source_id]'"
        exit 1
      end

      puts "✓ Source: #{source.name} (ID: #{source.id}, Code: #{source.code})"
      puts ""

      # Step 2: Get all New Testament books
      nt_book_codes = VerseCountReference::NEW_TESTAMENT_BOOKS
      puts "New Testament books to process: #{nt_book_codes.count}"
      puts ""

      # Step 3: Create all text_content records for all books
      puts "=" * 80
      puts "STEP 1: Creating Text Content Records"
      puts "=" * 80
      puts ""

      total_created = 0
      total_existing = 0
      creation_errors = []

      nt_book_codes.each_with_index do |book_code, index|
        puts "[#{index + 1}/#{nt_book_codes.count}] Processing: #{book_code}"

        # Find or create book
        book = Book.unscoped.find_by(code: book_code)
        unless book
          # Try to find by std_name
          book = Book.unscoped.where('std_name ILIKE ?', "%#{book_code}%").first
          unless book
            puts "  ⚠ Book #{book_code} not found, skipping..."
            next
          end
        end

        puts "  Book: #{book.std_name} (#{book.code})"

        # Get chapters for this book
        chapters = VerseCountReference.chapters_for_book(book_code)
        
        if chapters.empty?
          puts "  ⚠ No verse count data for #{book_code}, skipping..."
          next
        end

        puts "  Chapters: #{chapters.count}"

        # Create all verses for this book
        book_created = 0
        book_existing = 0

        chapters.each do |chapter|
          verse_count = VerseCountReference.expected_verses(book_code, chapter)
          next unless verse_count

          (1..verse_count).each do |verse|
            # Check if already exists
            existing = TextContent.unscoped.find_by(
              source_id: source.id,
              book_id: book.id,
              unit_group: chapter,
              unit: verse
            )

            if existing
              book_existing += 1
              next unless force_create
            end

            # Create new record
            begin
              unit_key = "#{source.code}|#{book.code}|#{chapter}|#{verse}"
              
              text_unit_type = source.text_unit_type || TextUnitType.unscoped.find_by(code: 'BIB_VERSE')
              language = source.language

              unless text_unit_type && language
                creation_errors << { book: book_code, chapter: chapter, verse: verse, error: "Missing text_unit_type or language" }
                next
              end

              text_content = TextContent.new(
                source: source,
                book: book,
                text_unit_type: text_unit_type,
                language: language,
                unit_group: chapter,
                unit: verse,
                unit_key: unit_key,
                content: '',
                allow_empty_content: true,
                population_status: 'pending'
              )

              if text_content.save
                book_created += 1
              else
                creation_errors << { book: book_code, chapter: chapter, verse: verse, error: text_content.errors.full_messages.join(', ') }
              end
            rescue => e
              creation_errors << { book: book_code, chapter: chapter, verse: verse, error: e.message }
            end
          end
        end

        total_created += book_created
        total_existing += book_existing

        puts "  ✓ Created: #{book_created}, Existing: #{book_existing}"
        puts ""
      end

      puts "=" * 80
      puts "Creation Summary"
      puts "=" * 80
      puts "Total created: #{total_created}"
      puts "Total existing: #{total_existing}"
      puts "Errors: #{creation_errors.count}"
      puts ""

      if creation_errors.any?
        puts "Creation errors (first 10):"
        creation_errors.first(10).each do |error|
          puts "  - #{error[:book]} #{error[:chapter]}:#{error[:verse]}: #{error[:error]}"
        end
        puts ""
      end

      # Step 4: Populate all created records
      puts "=" * 80
      puts "STEP 2: Populating Text Content"
      puts "=" * 80
      puts ""
      puts "Model: #{model}"
      puts "Max Concurrent: #{max_concurrent}"
      puts "Batch Size: #{batch_size}"
      puts "Force: #{force_populate ? 'YES (will overwrite existing)' : 'NO (skip existing)'}"
      puts ""

      # Get scope of verses to populate
      scope = TextContent.unscoped.where(source_id: source.id)
      
      unless force_populate
        # Skip already successfully populated
        scope = scope.where.not(population_status: 'success')
      end

      total_to_populate = scope.count

      if total_to_populate == 0
        puts "✓ No verses to populate (all already populated)"
        exit 0
      end

      puts "Found #{total_to_populate} verse(s) to populate"
      puts ""

      # Process in batches using concurrent futures
      require 'concurrent'
      
      processed = 0
      success_count = 0
      error_count = 0
      start_time = Time.current

      scope.find_in_batches(batch_size: batch_size) do |batch|
        puts "Processing batch of #{batch.size} verses (#{processed + 1} to #{processed + batch.size} of #{total_to_populate})..."
        
        # Create concurrent futures for this batch
        futures = batch.map do |tc|
          Concurrent::Future.execute do
            begin
              service = TextContentPopulationService.new(tc)
              result = service.populate_content_fields(force: force_populate)
              # Ensure result is always a hash with status
              if result.nil?
                Rails.logger.error "Service returned nil for #{tc.unit_key}"
                { status: 'error', error: 'Service returned nil' }
              elsif !result.is_a?(Hash)
                Rails.logger.error "Service returned non-hash for #{tc.unit_key}: #{result.class}"
                { status: 'error', error: "Invalid result format: #{result.class}" }
              elsif !result.key?(:status)
                Rails.logger.error "Service result missing :status key for #{tc.unit_key}: #{result.keys.inspect}"
                { status: 'error', error: 'Result missing :status key' }
              else
                result
              end
            rescue => e
              # Ensure we always return a hash with status
              Rails.logger.error "Exception in future for #{tc.unit_key}: #{e.class.name}: #{e.message}"
              Rails.logger.error e.backtrace.first(3).join("\n")
              { status: 'error', error: "#{e.class.name}: #{e.message}" }
            end
          end
        end

        # Wait for all futures in this batch to complete
        results = futures.map.with_index do |future, idx|
          begin
            # Use wait with timeout, then get value
            if future.wait(300) # Wait up to 5 minutes
              result = future.value
            else
              Rails.logger.error "Future #{idx} timed out after 5 minutes"
              { status: 'error', error: 'Request timed out after 5 minutes' }
            end
            # Ensure result is always a hash with status
            if result.nil?
              Rails.logger.error "Future #{idx} returned nil"
              { status: 'error', error: 'Future returned nil' }
            elsif !result.is_a?(Hash)
              Rails.logger.error "Future #{idx} returned non-hash: #{result.class}"
              { status: 'error', error: "Invalid result format: #{result.class}" }
            elsif !result.key?(:status)
              Rails.logger.error "Future #{idx} result missing :status key: #{result.keys.inspect}"
              { status: 'error', error: 'Result missing :status key' }
            else
              result
            end
          rescue Concurrent::TimeoutError => e
            Rails.logger.error "Future #{idx} timed out after 5 minutes"
            { status: 'error', error: 'Request timed out after 5 minutes' }
          rescue => e
            # Handle exceptions from futures
            Rails.logger.error "Exception getting future #{idx} value: #{e.class.name}: #{e.message}"
            { status: 'error', error: "#{e.class.name}: #{e.message}" }
          end
        end
        
        # Count successes and errors
        batch_success = results.count { |r| r && r.is_a?(Hash) && r[:status] == 'success' }
        batch_errors = results.count { |r| r && r.is_a?(Hash) && r[:status] == 'error' }
        
        success_count += batch_success
        error_count += batch_errors
        processed += batch.size

        # Progress bar
        progress = (processed.to_f / total_to_populate * 100).round(1)
        bar_length = 50
        filled = (progress / 100.0 * bar_length).floor
        bar = '█' * filled + '░' * (bar_length - filled)
        
        puts "  Batch complete | #{processed}/#{total_to_populate} (#{progress}%) | Success: #{batch_success}/#{batch.size} | Errors: #{batch_errors} | [#{bar}]"
        puts ""
      end

      elapsed = Time.current - start_time
      elapsed_minutes = (elapsed / 60.0).round(2)

      puts "=" * 80
      puts "Population Complete"
      puts "=" * 80
      puts "Total processed: #{processed}"
      puts "  - Success: #{success_count}"
      puts "  - Errors: #{error_count}"
      puts "  - Already populated: #{processed - success_count - error_count}"
      puts "Time elapsed: #{elapsed_minutes} minutes"
      puts "Average: #{(elapsed / processed).round(2)} seconds per verse" if processed > 0
      puts ""

      # Show error summary if any
      if error_count > 0
        error_records = scope.where(population_status: 'error').limit(10)
        if error_records.any?
          puts "Sample errors:"
          error_records.each do |tc|
            puts "  - #{tc.unit_key}: #{tc.population_error_message&.truncate(80)}"
          end
          puts ""
        end
        puts "⚠ Run with FORCE_POPULATE=true to retry errors, or use: rake 'lexical:resume[#{source.id}]'"
      end

      puts ""
      puts "=" * 80
      puts "Complete Summary"
      puts "=" * 80
      puts "Records created: #{total_created}"
      puts "Records existing: #{total_existing}"
      puts "Records populated: #{success_count}"
      puts "Records with errors: #{error_count}"
      puts "Total time: #{elapsed_minutes} minutes"
      puts ""
      puts "Done!"
    end

    desc "Monitor job status and alert if issues. Usage: rake 'lexical:monitor[source_id]'"
    task :monitor, [:source_id] => :environment do |t, args|
      source_id = args[:source_id]&.to_i || 10
      
      scope = TextContent.unscoped.where(source_id: source_id)
      total = scope.count
      success = scope.where(population_status: 'success').count
      error = scope.where(population_status: 'error').count
      pending = scope.where(population_status: ['pending', nil]).count
      processing = scope.where(population_status: 'processing').count
      
      # Check for stuck jobs (processing > 1 hour)
      stuck = scope.where(population_status: 'processing')
                   .where('last_population_attempt_at < ?', 1.hour.ago)
                   .count
      
      error_rate = total > 0 ? (error.to_f / total * 100) : 0
      success_rate = total > 0 ? (success.to_f / total * 100) : 0
      
      puts "=" * 80
      puts "Job Status Monitor - Source ID: #{source_id}"
      puts "=" * 80
      puts ""
      puts "Summary:"
      puts "  Total: #{total}"
      puts "  Success: #{success} (#{success_rate.round(1)}%)"
      puts "  Error: #{error} (#{error_rate.round(1)}%)"
      puts "  Pending: #{pending}"
      puts "  Processing: #{processing}"
      puts "  Stuck (>1hr): #{stuck}"
      puts ""
      
      # Alert conditions
      alerts = []
      if error_rate > 5
        alerts << "⚠️  HIGH ERROR RATE: #{error_rate.round(1)}% (threshold: 5%)"
      end
      if stuck > 0
        alerts << "⚠️  STUCK JOBS: #{stuck} job(s) processing for >1 hour"
      end
      if processing > 50
        alerts << "⚠️  HIGH PROCESSING COUNT: #{processing} jobs currently processing"
      end
      
      if alerts.any?
        puts "ALERTS:"
        alerts.each { |alert| puts "  #{alert}" }
        puts ""
        exit 1 # Exit with error code for monitoring tools
      else
        puts "✓ Status OK"
        exit 0
      end
    end

    desc "Enqueue Westcott-Hort NT population job via Sidekiq. Usage: rake 'lexical:enqueue_wh_nt_job[source_id]' or with FORCE_CREATE=true FORCE_POPULATE=true"
    task :enqueue_wh_nt_job, [:source_id] => :environment do |t, args|
      source_id = args[:source_id]&.to_i || 10
      force_create = ENV['FORCE_CREATE'] == 'true'
      force_populate = ENV['FORCE_POPULATE'] == 'true'
      
      puts "=" * 80
      puts "Enqueuing PopulateWestcottHortNtJob"
      puts "=" * 80
      puts "Source ID: #{source_id}"
      puts "Force Create: #{force_create ? 'YES' : 'NO'}"
      puts "Force Populate: #{force_populate ? 'YES' : 'NO'}"
      puts ""
      
      # Check if already completed (unless forcing)
      unless force_populate
        source = Source.unscoped.find_by(id: source_id.to_i)
        if source
          total_verses = TextContent.unscoped.where(source_id: source.id).count
          success_verses = TextContent.unscoped.where(source_id: source.id, population_status: 'success').count
          completion_rate = total_verses > 0 ? (success_verses.to_f / total_verses * 100) : 0
          
          # Only consider complete if 100% successful (strict requirement)
          if success_verses == total_verses && total_verses > 0
            puts "⚠ Already completed (100% success - #{success_verses}/#{total_verses} verses)"
            puts "Use FORCE_POPULATE=true to rerun"
            exit 0
          end
        end
      end
      
      # Enqueue the job (using ActiveJob's perform_later which works with Sidekiq)
      job = PopulateWestcottHortNtJob.perform_later(source_id, force_create: force_create, force_populate: force_populate)
      
      if job
        puts "✓ Job enqueued successfully"
        puts "Job ID: #{job.job_id}"
        puts ""
        puts "Monitor progress at: /sidekiq"
        puts "Or check logs: heroku logs --tail --ps worker"
      else
        puts "✗ Failed to enqueue job"
        exit 1
      end
    end

    # ============================================================================
    # AUTOMATED CREATION AND POPULATION FOR SEPTUAGINT (H.B. SWETE 1894–1909)
    # ============================================================================

    desc "Create and populate test verses for Septuagint LXX (runs synchronously). Usage: rake 'lexical:create_and_populate_lxx_test_verses[source_id]' or with FORCE=true"
    task :create_and_populate_lxx_test_verses, [:source_id] => :environment do |t, args|
      source_id = args[:source_id]&.to_i
      force = ENV['FORCE'] == 'true'

      puts "=" * 80
      puts "Create and Populate Septuagint (H.B. Swete) Test Verses"
      puts "=" * 80
      puts ""

      # Step 1: Find or create Septuagint Swete source
      source = if source_id
        Source.unscoped.find_by(id: source_id.to_i)
      else
        # Try to find by name variations
        Source.unscoped.where('name ILIKE ? OR name ILIKE ? OR name ILIKE ? OR code ILIKE ?',
                              '%Swete%', '%Septuagint%', '%LXX%', '%SWETE%').first
      end

      unless source
        # Create the source if it doesn't exist
        language = Language.unscoped.find_by(code: 'grc')
        unless language
          puts "✗ Greek language not found. Please seed languages first."
          exit 1
        end

        source = Source.create!(
          code: 'LXX_SWETE',
          name: 'Septuagint (H.B. Swete 1894–1909)',
          description: 'The Old Testament in Greek according to the Septuagint, edited by H.B. Swete',
          language: language
        )
        puts "✓ Created new source: #{source.name} (ID: #{source.id}, Code: #{source.code})"
      else
        puts "✓ Found source: #{source.name} (ID: #{source.id}, Code: #{source.code})"
      end
      puts ""

      # Define test verses
      test_verses = [
        # 1. Genesis 1:1–2
        { book: 'GEN', chapter: 1, verses: [1, 2], description: 'Tests basic syntax, prepositions, and orthography' },
        # 2. Exodus 3:14
        { book: 'EXO', chapter: 3, verses: [14], description: 'Key existential construction: ἐγώ εἰμι ὁ ὤν - Critical for LSV behavior' },
        # 3. Isaiah 7:14
        { book: 'ISA', chapter: 7, verses: [14], description: 'Check παρθένος + Swete\'s notes if present' },
        # 4. Isaiah 9:5–6 LXX
        { book: 'ISA', chapter: 9, verses: [5, 6], description: 'Long compound titles; punctuation stress test' },
        # 5. Psalm 109:3 LXX (110:3 MT)
        { book: 'PSA', chapter: 109, verses: [3], description: 'Poetry formatting + theological nuance' },
        # 6. Psalm 44:7–8 LXX (45:6–7 MT)
        { book: 'PSA', chapter: 44, verses: [7, 8], description: 'OT parallel to Hebrews 1:8–9; perfect comparison case' },
        # 7. Job 42:17 (Tests Hexaplaric symbols)
        { book: 'JOB', chapter: 42, verses: [17], description: 'Tests Hexaplaric symbols (*, ÷, etc.) where Swete uses them' },
        # 8. Proverbs 8:22–25
        { book: 'PRO', chapter: 8, verses: [22, 23, 24, 25], description: 'Key theological text: κύριος ἔκτισέν με - Also sometimes contains critical marks' },
        # 9. Daniel 3:25 (Theodotion)
        { book: 'DAN', chapter: 3, verses: [25], description: 'Ensures Theodotion material parses correctly' },
        # 10. Daniel 13 (Susanna) — treated as Daniel 13, NOT a separate book
        { book: 'DAN', chapter: 13, verses: [1, 23, 24, 63], description: 'Secondary Greek tradition incorporation - Proper handling of extended narrative structure' },
        # 11. Optional: Daniel 14 (Bel and the Dragon)
        { book: 'DAN', chapter: 14, verses: [1], description: 'Bel and the Dragon - treated as Daniel chapter 14' }
      ]

      total_test_verses = test_verses.sum { |tv| tv[:verses].count }
      puts "Test verses to process: #{total_test_verses}"
      puts ""

      # Step 1: Create text content records
      puts "=" * 80
      puts "STEP 1: Creating Text Content Records"
      puts "=" * 80
      puts ""

      total_created = 0
      total_existing = 0
      creation_errors = []

      test_verses.each_with_index do |test_verse, idx|
        book_code = test_verse[:book]
        chapter = test_verse[:chapter]
        description = test_verse[:description]

        puts "[#{idx + 1}/#{test_verses.count}] #{book_code} #{chapter} - #{description}"

        # Find book
        book = Book.unscoped.find_by(code: book_code)
        unless book
          creation_errors << { book: book_code, chapter: chapter, error: "Book not found" }
          puts "  ✗ Book #{book_code} not found, skipping..."
          next
        end

        test_verse[:verses].each do |verse|
          # Check if already exists
          existing = TextContent.unscoped.find_by(
            source_id: source.id,
            book_id: book.id,
            unit_group: chapter,
            unit: verse
          )

          if existing
            total_existing += 1
            puts "  → Exists: #{book.std_name} #{chapter}:#{verse}"
            next unless force
          end

          # Create new record
          begin
            unit_key = "#{source.code}|#{book.code}|#{chapter}|#{verse}"
            
            text_unit_type = source.text_unit_type || TextUnitType.unscoped.find_by(code: 'BIB_VERSE')
            language = source.language

            unless text_unit_type && language
              creation_errors << { book: book_code, chapter: chapter, verse: verse, error: "Missing text_unit_type or language" }
              next
            end

            text_content = TextContent.new(
              source: source,
              book: book,
              text_unit_type: text_unit_type,
              language: language,
              unit_group: chapter,
              unit: verse,
              unit_key: unit_key,
              content: '',
              allow_empty_content: true,
              population_status: 'pending'
            )

            if text_content.save
              total_created += 1
              puts "  ✓ Created: #{book.std_name} #{chapter}:#{verse}"
            else
              creation_errors << { book: book_code, chapter: chapter, verse: verse, error: text_content.errors.full_messages.join(', ') }
              puts "  ✗ Error: #{text_content.errors.full_messages.join(', ')}"
            end
          rescue => e
            creation_errors << { book: book_code, chapter: chapter, verse: verse, error: e.message }
            puts "  ✗ Exception: #{e.message}"
          end
        end
        puts ""
      end

      puts "=" * 80
      puts "Creation Summary"
      puts "=" * 80
      puts "Total created: #{total_created}"
      puts "Total existing: #{total_existing}"
      puts "Errors: #{creation_errors.count}"
      puts ""

      if creation_errors.any?
        puts "Creation errors:"
        creation_errors.each do |error|
          puts "  - #{error[:book]} #{error[:chapter]}:#{error[:verse]}: #{error[:error]}"
        end
        puts ""
      end

      # Step 2: Populate all test verses
      puts "=" * 80
      puts "STEP 2: Populating Test Verses"
      puts "=" * 80
      puts ""

      # Get all test verse records
      test_verse_records = []
      test_verses.each do |test_verse|
        book = Book.unscoped.find_by(code: test_verse[:book])
        next unless book

        test_verse[:verses].each do |verse|
          record = TextContent.unscoped.find_by(
            source_id: source.id,
            book_id: book.id,
            unit_group: test_verse[:chapter],
            unit: verse
          )
          test_verse_records << record if record
        end
      end

      puts "Found #{test_verse_records.count} test verse record(s) to populate"
      puts ""

      if test_verse_records.empty?
        puts "✗ No test verse records found to populate"
        exit 1
      end

      # Populate each verse with deterministic validation and retry logic
      stats = {
        total: test_verse_records.count,
        populated: 0,
        already_populated: 0,
        errors: []
      }

      test_verse_records.each_with_index do |text_content, index|
        book = text_content.book
        chapter = text_content.unit_group
        verse = text_content.unit
        
        puts "[#{index + 1}/#{test_verse_records.count}] Populating: #{book.std_name} #{chapter}:#{verse} (#{text_content.unit_key})"

        max_retries = 3
        retry_count = 0
        populated_successfully = false

        while retry_count < max_retries && !populated_successfully
          begin
            population_service = TextContentPopulationService.new(text_content.reload)
            population_result = population_service.populate_content_fields(force: force || retry_count > 0)

            case population_result[:status]
            when 'success'
              stats[:populated] += 1
              puts "  ✓ Populated successfully (deterministic validators passed)"
              populated_successfully = true
            when 'already_populated'
              stats[:already_populated] += 1
              puts "  → Already populated (skipped population; use FORCE=true to repopulate)"
              populated_successfully = true
            when 'needs_repair'
              stats[:errors] << { book: book.code, chapter: chapter, verse: verse, error: "Needs repair: #{population_result[:error]}" }
              puts "  ✗ Marked as needs_repair: #{population_result[:error]}"
              populated_successfully = true
            else
              retry_count += 1
              if retry_count < max_retries
                puts "  ⚠ Population failed (retry #{retry_count}/#{max_retries}): #{population_result[:error]}"
                sleep 2
                next
              else
                stats[:errors] << { book: book.code, chapter: chapter, verse: verse, error: population_result[:error] }
                puts "  ✗ Failed after #{max_retries} retries: #{population_result[:error]}"
                populated_successfully = true  # Stop retrying
              end
            end
          rescue => e
            retry_count += 1
            if retry_count < max_retries
              puts "  ⚠ Exception (retry #{retry_count}/#{max_retries}): #{e.message}"
              sleep 2
              next
            else
              stats[:errors] << { book: book.code, chapter: chapter, verse: verse, error: e.message }
              puts "  ✗ Exception after #{max_retries} retries: #{e.message}"
              populated_successfully = true
            end
          end
        end

        puts ""
      end

      puts "=" * 80
      puts "Population Summary"
      puts "=" * 80
      puts "Total verses: #{stats[:total]}"
      puts "  - Newly populated (validators passed): #{stats[:populated]}"
      puts "  - Already populated (skipped): #{stats[:already_populated]}"
      puts "  - Errors: #{stats[:errors].count}"
      puts ""
      
      if stats[:errors].any?
        puts "Errors encountered:"
        stats[:errors].each do |error|
          puts "  - #{error[:book]} #{error[:chapter]}:#{error[:verse]}: #{error[:error]}"
        end
        puts ""
      end

      puts "=" * 80
      puts "Complete Summary"
      puts "=" * 80
      puts "Records created: #{total_created}"
      puts "Records existing: #{total_existing}"
      puts "Verses populated (validators passed): #{stats[:populated]}"
      puts "Verses already populated (skipped): #{stats[:already_populated]}"
      puts "Errors: #{stats[:errors].count}"
      puts ""
      puts "Done!"
    end

    desc "Create and populate test verses for Septuagint LXX (runs synchronously). Usage: rake 'lexical:create_and_populate_lxx_test_verses[source_id]' or with FORCE=true"
    task :create_and_populate_lxx_test_verses, [:source_id] => :environment do |t, args|
      source_id = args[:source_id]&.to_i
      force = ENV['FORCE'] == 'true'
      
      puts "=" * 80
      puts "Create and Populate Septuagint LXX Test Verses"
      puts "=" * 80
      puts "Source ID: #{source_id || 'AUTO (will find or create)'}"
      puts "Force: #{force ? 'YES (will overwrite existing)' : 'NO (skip existing)'}"
      puts ""
      
      # Find or create source
      source = if source_id
        Source.unscoped.find_by(id: source_id.to_i)
      else
        Source.unscoped.where('name ILIKE ? OR name ILIKE ? OR name ILIKE ? OR code ILIKE ?',
                              '%Swete%', '%Septuagint%', '%LXX%', '%SWETE%').first
      end

      unless source
        language = Language.unscoped.find_by(code: 'grc')
        unless language
          puts "✗ Greek language not found. Please seed languages first."
          exit 1
        end

        source = Source.create!(
          code: 'LXX_SWETE',
          name: 'Septuagint (H.B. Swete 1894–1909)',
          description: 'The Old Testament in Greek according to the Septuagint, edited by H.B. Swete',
          language: language
        )
        puts "✓ Created new source: #{source.name} (ID: #{source.id})"
      else
        puts "✓ Found source: #{source.name} (ID: #{source.id})"
      end
      puts ""

      # Define test verses
      test_verses = [
        # 1. Genesis 1:1–2
        { book: 'GEN', chapter: 1, verses: [1, 2], description: 'Tests basic syntax, prepositions, and orthography' },
        # 2. Exodus 3:14
        { book: 'EXO', chapter: 3, verses: [14], description: 'Key existential construction: ἐγώ εἰμι ὁ ὤν - Critical for LSV behavior' },
        # 3. Isaiah 7:14
        { book: 'ISA', chapter: 7, verses: [14], description: 'Check παρθένος + Swete\'s notes if present' },
        # 4. Isaiah 9:5–6 LXX
        { book: 'ISA', chapter: 9, verses: [5, 6], description: 'Long compound titles; punctuation stress test' },
        # 5. Psalm 109:3 LXX (110:3 MT)
        { book: 'PSA', chapter: 109, verses: [3], description: 'Poetry formatting + theological nuance' },
        # 6. Psalm 44:7–8 LXX (45:6–7 MT)
        { book: 'PSA', chapter: 44, verses: [7, 8], description: 'OT parallel to Hebrews 1:8–9; perfect comparison case' },
        # 7. Job 42:17 (Tests Hexaplaric symbols)
        { book: 'JOB', chapter: 42, verses: [17], description: 'Tests Hexaplaric symbols (*, ÷, etc.) where Swete uses them' },
        # 8. Proverbs 8:22–25
        { book: 'PRO', chapter: 8, verses: [22, 23, 24, 25], description: 'Key theological text: κύριος ἔκτισέν με - Also sometimes contains critical marks' },
        # 9. Daniel 3:25 (Theodotion)
        { book: 'DAN', chapter: 3, verses: [25], description: 'Ensures Theodotion material parses correctly' },
        # 10. Daniel 13 (Susanna) — treated as Daniel 13, NOT a separate book
        { book: 'DAN', chapter: 13, verses: [1, 23, 24, 63], description: 'Secondary Greek tradition incorporation - Proper handling of extended narrative structure' },
        # 11. Optional: Daniel 14 (Bel and the Dragon)
        { book: 'DAN', chapter: 14, verses: [1], description: 'Bel and the Dragon - treated as Daniel chapter 14' }
      ]

      total_test_verses = test_verses.sum { |tv| tv[:verses].count }
      puts "Test verses to process: #{total_test_verses}"
      puts ""

      # Step 1: Create text content records
      puts "=" * 80
      puts "STEP 1: Creating Text Content Records"
      puts "=" * 80
      puts ""

      total_created = 0
      total_existing = 0
      creation_errors = []

      test_verses.each_with_index do |test_verse, idx|
        book_code = test_verse[:book]
        chapter = test_verse[:chapter]
        description = test_verse[:description]

        puts "[#{idx + 1}/#{test_verses.count}] #{book_code} #{chapter} - #{description}"

        # Find book
        book = Book.unscoped.find_by(code: book_code)
        unless book
          creation_errors << { book: book_code, chapter: chapter, error: "Book not found" }
          puts "  ✗ Book #{book_code} not found, skipping..."
          next
        end

        test_verse[:verses].each do |verse|
          # Check if already exists
          existing = TextContent.unscoped.find_by(
            source_id: source.id,
            book_id: book.id,
            unit_group: chapter,
            unit: verse
          )

          if existing
            total_existing += 1
            puts "  → Exists: #{book.std_name} #{chapter}:#{verse}"
            next unless force
          end

          # Create new record
          begin
            unit_key = "#{source.code}|#{book.code}|#{chapter}|#{verse}"
            
            text_unit_type = source.text_unit_type || TextUnitType.unscoped.find_by(code: 'BIB_VERSE')
            language = source.language

            unless text_unit_type && language
              creation_errors << { book: book_code, chapter: chapter, verse: verse, error: "Missing text_unit_type or language" }
              next
            end

            text_content = TextContent.new(
              source: source,
              book: book,
              text_unit_type: text_unit_type,
              language: language,
              unit_group: chapter,
              unit: verse,
              unit_key: unit_key,
              content: '',
              allow_empty_content: true,
              population_status: 'pending'
            )

            if text_content.save
              total_created += 1
              puts "  ✓ Created: #{book.std_name} #{chapter}:#{verse}"
            else
              creation_errors << { book: book_code, chapter: chapter, verse: verse, error: text_content.errors.full_messages.join(', ') }
              puts "  ✗ Error: #{text_content.errors.full_messages.join(', ')}"
            end
          rescue => e
            creation_errors << { book: book_code, chapter: chapter, verse: verse, error: e.message }
            puts "  ✗ Exception: #{e.message}"
          end
        end
        puts ""
      end

      puts "=" * 80
      puts "Creation Summary"
      puts "=" * 80
      puts "Total created: #{total_created}"
      puts "Total existing: #{total_existing}"
      puts "Errors: #{creation_errors.count}"
      puts ""

      if creation_errors.any?
        puts "Creation errors:"
        creation_errors.each do |error|
          puts "  - #{error[:book]} #{error[:chapter]}:#{error[:verse]}: #{error[:error]}"
        end
        puts ""
      end

      # Step 2: Populate all test verses
      puts "=" * 80
      puts "STEP 2: Populating Test Verses"
      puts "=" * 80
      puts ""

      # Get all test verse records
      test_verse_records = []
      test_verses.each do |test_verse|
        book = Book.unscoped.find_by(code: test_verse[:book])
        next unless book

        test_verse[:verses].each do |verse|
          record = TextContent.unscoped.find_by(
            source_id: source.id,
            book_id: book.id,
            unit_group: test_verse[:chapter],
            unit: verse
          )
          test_verse_records << record if record
        end
      end

      puts "Found #{test_verse_records.count} test verse record(s) to populate"
      puts ""

      if test_verse_records.empty?
        puts "✗ No test verse records found to populate"
        exit 1
      end

      # Populate each verse with deterministic validation and retry logic
      stats = {
        total: test_verse_records.count,
        populated: 0,
        already_populated: 0,
        errors: []
      }

      test_verse_records.each_with_index do |text_content, index|
        book = text_content.book
        chapter = text_content.unit_group
        verse = text_content.unit
        
        puts "[#{index + 1}/#{test_verse_records.count}] Populating: #{book.std_name} #{chapter}:#{verse} (#{text_content.unit_key})"

        max_retries = 3
        retry_count = 0
        populated_successfully = false

        while retry_count < max_retries && !populated_successfully
          begin
            population_service = TextContentPopulationService.new(text_content.reload)
            population_result = population_service.populate_content_fields(force: force || retry_count > 0)

            if population_result[:status] == 'success'
              stats[:populated] += 1
              puts "  ✓ Populated successfully (deterministic validators passed)"
              populated_successfully = true
            elsif population_result[:status] == 'already_populated'
              stats[:already_populated] += 1
              puts "  → Already populated (skipped population; use FORCE=true to repopulate)"
              populated_successfully = true
            elsif population_result[:status] == 'needs_repair'
              stats[:errors] << { book: book.code, chapter: chapter, verse: verse, error: "Needs repair: #{population_result[:error]}" }
              puts "  ✗ Marked as needs_repair: #{population_result[:error]}"
              populated_successfully = true
            else
              retry_count += 1
              if retry_count < max_retries
                puts "  ⚠ Population failed (retry #{retry_count}/#{max_retries}): #{population_result[:error]}"
                sleep 2
                next
              else
                stats[:errors] << { book: book.code, chapter: chapter, verse: verse, error: population_result[:error] }
                puts "  ✗ Failed after #{max_retries} retries: #{population_result[:error]}"
                populated_successfully = true  # Stop retrying
              end
            end
          rescue => e
            retry_count += 1
            if retry_count < max_retries
              puts "  ⚠ Exception (retry #{retry_count}/#{max_retries}): #{e.message}"
              sleep 2
              next
            else
              stats[:errors] << { book: book.code, chapter: chapter, verse: verse, error: e.message }
              puts "  ✗ Exception after #{max_retries} retries: #{e.message}"
              populated_successfully = true
            end
          end
        end

        puts ""
      end

      puts "=" * 80
      puts "Population Summary"
      puts "=" * 80
      puts "Total verses: #{stats[:total]}"
      puts "  - Newly populated (validators passed): #{stats[:populated]}"
      puts "  - Already populated (skipped): #{stats[:already_populated]}"
      puts "  - Errors: #{stats[:errors].count}"
      puts ""
      
      if stats[:errors].any?
        puts "Errors encountered:"
        stats[:errors].each do |error|
          puts "  - #{error[:book]} #{error[:chapter]}:#{error[:verse]}: #{error[:error]}"
        end
        puts ""
      end

      puts "=" * 80
      puts "Complete Summary"
      puts "=" * 80
      puts "Records created: #{total_created}"
      puts "Records existing: #{total_existing}"
      puts "Verses populated (validators passed): #{stats[:populated]}"
      puts "Verses already populated (skipped): #{stats[:already_populated]}"
      puts "Errors: #{stats[:errors].count}"
      puts ""
      puts "Done!"
    end

    desc "Enqueue Septuagint LXX population job via Sidekiq. Usage: rake 'lexical:enqueue_lxx_job[source_id]' or with FORCE_CREATE=true FORCE_POPULATE=true"
    task :enqueue_lxx_job, [:source_id] => :environment do |t, args|
      source_id = args[:source_id]&.to_i
      force_create = ENV['FORCE_CREATE'] == 'true'
      force_populate = ENV['FORCE_POPULATE'] == 'true'
      
      puts "=" * 80
      puts "Enqueuing PopulateSeptuagintLxxJob"
      puts "=" * 80
      puts "Source ID: #{source_id || 'AUTO (will find or create)'}"
      puts "Force Create: #{force_create ? 'YES' : 'NO'}"
      puts "Force Populate: #{force_populate ? 'YES' : 'NO'}"
      puts ""
      
      # Check if already completed (unless forcing)
      unless force_populate
        source = if source_id
          Source.unscoped.find_by(id: source_id.to_i)
        else
          Source.unscoped.where('name ILIKE ? OR name ILIKE ? OR name ILIKE ? OR code ILIKE ?',
                                '%Swete%', '%Septuagint%', '%LXX%', '%SWETE%').first
        end
        
        if source
          total_verses = TextContent.unscoped.where(source_id: source.id).count
          success_verses = TextContent.unscoped.where(source_id: source.id, population_status: 'success').count
          completion_rate = total_verses > 0 ? (success_verses.to_f / total_verses * 100) : 0
          
          # Only consider complete if 100% successful (strict requirement)
          if success_verses == total_verses && total_verses > 0
            puts "⚠ Already completed (100% success - #{success_verses}/#{total_verses} verses)"
            puts "Use FORCE_POPULATE=true to rerun"
            exit 0
          end
        end
      end
      
      # Enqueue the job (using ActiveJob's perform_later which works with Sidekiq)
      job = PopulateSeptuagintLxxJob.perform_later(source_id, force_create: force_create, force_populate: force_populate)
      
      if job
        puts "✓ Job enqueued successfully"
        puts "Job ID: #{job.job_id}"
        puts ""
        puts "Monitor progress at: /sidekiq"
        puts "Or check logs: heroku logs --tail --ps worker"
        puts ""
        puts "This job will:"
        puts "  1. Create or find Septuagint Swete source"
        puts "  2. Create text content records for ALL Old Testament books (all chapters, all verses)"
        puts "  3. Enqueue individual TextContentPopulateJob for each verse"
        puts ""
        puts "Note: Make sure OLD_TESTAMENT_VERSE_COUNTS in VerseCountReference has verse counts"
        puts "      for all OT books you want to process."
      else
        puts "✗ Failed to enqueue job"
        exit 1
      end
    end
  end


