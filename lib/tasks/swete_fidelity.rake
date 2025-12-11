namespace :swete do
  desc "Audit entire Swete source against canonical text. Usage: rake swete:audit_fidelity"
  task audit_fidelity: :environment do
    puts "=" * 80
    puts "Swete 1894 Fidelity Audit"
    puts "=" * 80
    puts ""

    source = Source.unscoped.find_by(code: 'LXX_SWETE') || 
             Source.unscoped.where('name ILIKE ? OR code ILIKE ?', '%Swete%', '%SWETE%').first

    unless source
      puts "✗ Swete source not found"
      exit 1
    end

    puts "Source: #{source.name} (ID: #{source.id}, Code: #{source.code})"
    puts ""

    # Get all Swete text contents
    text_contents = TextContent.unscoped.where(source_id: source.id)
                                .where.not(content: [nil, ''])
                                .order(:book_id, :unit_group, :unit)
                                .includes(:book)

    total_verses = text_contents.count
    puts "Total verses to audit: #{total_verses}"
    puts ""

    errors = []
    missing_canonical = []
    verified = 0

    text_contents.find_each.with_index do |text_content, index|
      book_code = text_content.book.code
      chapter = text_content.unit_group
      verse = text_content.unit

      begin
        validator = SweteFidelityValidator.new(
          source.code,
          book_code,
          chapter,
          verse
        )

        if validator.canonical_exists?
          validator.verify(text_content.content)
          verified += 1
        else
          missing_canonical << "#{book_code} #{chapter}:#{verse}"
        end
      rescue SweteFidelityError => e
        errors << {
          unit_key: text_content.unit_key,
          book: book_code,
          chapter: chapter,
          verse: verse,
          error: e.message
        }
      end

      # Progress indicator
      if (index + 1) % 100 == 0
        puts "Processed #{index + 1}/#{total_verses} verses... (Verified: #{verified}, Errors: #{errors.count}, Missing canonical: #{missing_canonical.count})"
      end
    end

    puts ""
    puts "=" * 80
    puts "Audit Summary"
    puts "=" * 80
    puts "Total verses audited: #{total_verses}"
    puts "  ✓ Verified (match canonical): #{verified}"
    puts "  ✗ Fidelity errors: #{errors.count}"
    puts "  ⚠ Missing canonical text: #{missing_canonical.count}"
    puts ""

    if errors.any?
      puts "=" * 80
      puts "Fidelity Errors (first 20):"
      puts "=" * 80
      errors.first(20).each do |error|
        puts "#{error[:unit_key]}: #{error[:error].split("\n").first}"
      end
      if errors.count > 20
        puts "... and #{errors.count - 20} more errors"
      end
      puts ""
    end

    if missing_canonical.any?
      puts "=" * 80
      puts "Verses Missing Canonical Text (first 20):"
      puts "=" * 80
      missing_canonical.first(20).each do |verse|
        puts "  - #{verse}"
      end
      if missing_canonical.count > 20
        puts "... and #{missing_canonical.count - 20} more"
      end
      puts ""
    end

    if errors.empty? && missing_canonical.empty?
      puts "✓ Audit passed: All verses with canonical text match perfectly!"
    elsif errors.empty?
      puts "⚠ Audit passed for verified verses, but #{missing_canonical.count} verses need canonical text added"
    else
      puts "✗ Audit failed: #{errors.count} verses have fidelity mismatches"
      puts "  Run with FORCE_POPULATE=true to re-process these verses"
      exit 1
    end

    puts ""
    puts "Done!"
  end

  desc "Import canonical Swete text from CSV. Usage: rake swete:import_canonical[path/to/file.csv]"
  task :import_canonical, [:csv_path] => :environment do |t, args|
    csv_path = args[:csv_path]
    
    unless csv_path && File.exist?(csv_path)
      puts "✗ CSV file not found: #{csv_path}"
      puts "Usage: rake swete:import_canonical[path/to/file.csv]"
      exit 1
    end

    puts "=" * 80
    puts "Importing Canonical Swete Text"
    puts "=" * 80
    puts "CSV file: #{csv_path}"
    puts ""

    require 'csv'
    
    imported = 0
    updated = 0
    errors = []

    CSV.foreach(csv_path, headers: true) do |row|
      begin
        source_code = row['source_code'] || 'LXX_SWETE'
        book_code = row['book_code']
        chapter = row['chapter_number'].to_i
        verse = row['verse_number'].to_s
        canonical_text = row['canonical_text']

        unless book_code && chapter && verse && canonical_text
          errors << "Missing required fields: #{row.inspect}"
          next
        end

        canonical = CanonicalSourceText.find_or_initialize_by(
          source_code: source_code,
          book_code: book_code,
          chapter_number: chapter,
          verse_number: verse
        )

        if canonical.new_record?
          imported += 1
        else
          updated += 1
        end

        canonical.canonical_text = canonical_text
        canonical.save!
      rescue => e
        errors << "Error importing row: #{e.message} - #{row.inspect}"
      end
    end

    puts "=" * 80
    puts "Import Summary"
    puts "=" * 80
    puts "Imported: #{imported}"
    puts "Updated: #{updated}"
    puts "Errors: #{errors.count}"
    puts ""

    if errors.any?
      puts "Errors (first 10):"
      errors.first(10).each do |error|
        puts "  - #{error}"
      end
      puts ""
    end

    puts "Done!"
  end
end

