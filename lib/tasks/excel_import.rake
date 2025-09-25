namespace :excel_import do
  desc "Import data from Excel files in data directory"
  task import: :environment do
    puts "Starting Excel import..."

    service = ExcelImportService.new

    # Do a dry run first
    puts "\n--- Dry Run ---"
    dry_run_results = service.dry_run

    dry_run_results.each do |filename, result|
      if result[:success]
        puts "#{filename}: #{result[:total_rows]} rows to import"
      else
        puts "#{filename}: ERROR - #{result[:error]}"
        exit 1
      end
    end

    # Ask for confirmation
    print "\nDo you want to proceed with the import? (y/n): "
    response = STDIN.gets.chomp.downcase

    if response == 'y'
      puts "\n--- Starting Import ---"

      # Clear existing data first
      puts "Clearing existing data..."
      service.clear_all_data

      # Import all files
      import_results = service.import_all_files

      puts "\n--- Import Results ---"
      total_imported = 0
      total_errors = 0

      import_results.each do |filename, result|
        if result[:success]
          puts "#{filename}: #{result[:imported_count]} records imported"
          total_imported += result[:imported_count]
          total_errors += result[:error_count]

          if result[:errors].any?
            puts "  Errors:"
            result[:errors].each { |error| puts "    #{error}" }
          end
        else
          puts "#{filename}: ERROR - #{result[:error]}"
          exit 1
        end
      end

      puts "\n--- Summary ---"
      puts "Total records imported: #{total_imported}"
      puts "Total errors: #{total_errors}"

      puts "\n--- Final Counts ---"
      service.instance_variable_get(:@file_mappings).each do |filename, config|
        count = config[:model].count
        puts "#{config[:model].name}: #{count} records"
      end

      puts "\nImport completed successfully!"
    else
      puts "Import cancelled."
    end
  end

  desc "Show dry run results without importing"
  task dry_run: :environment do
    puts "Excel Import Service - Dry Run"
    puts "=" * 40

    service = ExcelImportService.new
    dry_run_results = service.dry_run

    dry_run_results.each do |filename, result|
      if result[:success]
        puts "\n#{filename}:"
        puts "  Total rows: #{result[:total_rows]}"
        puts "  Existing records: #{result[:existing_records]}"
        puts "  Headers: #{result[:headers].join(', ')}"
      else
        puts "\n#{filename}: ERROR - #{result[:error]}"
      end
    end
  end

  desc "Clear all imported data"
  task clear: :environment do
    puts "Clearing all imported data..."

    service = ExcelImportService.new
    service.clear_all_data

    puts "All data cleared."
  end
end
