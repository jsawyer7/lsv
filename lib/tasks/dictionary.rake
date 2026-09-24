namespace :dictionary do
  desc "Import Wiktionary JSONL into dictionary_entries. DRY_RUN=true by default. LIVE: DRY_RUN=false TRUNCATE=true rake dictionary:import"
  task import: :environment do
    dry_run = ENV['DRY_RUN'] != 'false'
    truncate = ENV['TRUNCATE'] == 'true'
    limit = ENV['LIMIT'].presence&.to_i
    path = ENV['DICT_PATH'].presence || ImportWiktionaryDictionaryService::DEFAULT_PATH

    puts '=' * 80
    puts 'Import Wiktionary Dictionary'
    puts "Mode: #{dry_run ? 'DRY RUN' : 'LIVE'}"
    puts "Path: #{path}"
    puts "Truncate first: #{truncate}"
    puts "Limit: #{limit || 'none (full file)'}"
    puts '=' * 80

    begin
      result = ImportWiktionaryDictionaryService.new(
        path: path,
        dry_run: dry_run,
        limit: limit,
        truncate: truncate
      ).call
    rescue ImportWiktionaryDictionaryService::Error => e
      puts "✗ #{e.message}"
      exit 1
    end

    stats = result[:stats]
    puts ""
    puts "Lines read: #{stats[:lines_read]}"
    puts "Rows built: #{stats[:rows_built]}"
    puts "Inserted: #{stats[:inserted]}"
    puts "Parse errors: #{stats[:parse_errors]}"
    puts "Blank skipped: #{stats[:skipped_blank]}"
    puts "Max line bytes: #{stats[:max_line_bytes]} (line #{stats[:max_line_number]})"
    puts "Elapsed: #{result[:elapsed_seconds]}s"

    if result[:warnings].any?
      puts ""
      puts "Warnings (#{result[:warnings].size}):"
      result[:warnings].first(10).each { |w| puts "  - #{w}" }
    end

    if result[:errors].any?
      puts ""
      puts "Errors (#{result[:errors].size}):"
      result[:errors].first(20).each { |e| puts "  - #{e}" }
      exit 1
    end

    if dry_run
      puts ""
      puts "DRY RUN complete. To import for real:"
      puts "  DRY_RUN=false TRUNCATE=true rake dictionary:import"
    else
      puts ""
      puts "✓ Import finished. Run: rake dictionary:verify"
    end
  end

  desc "Verify dictionary_entries matches the JSONL letter-for-letter. Optional LIMIT=n"
  task verify: :environment do
    limit = ENV['LIMIT'].presence&.to_i
    path = ENV['DICT_PATH'].presence || VerifyWiktionaryDictionaryImportService::DEFAULT_PATH

    puts '=' * 80
    puts 'Verify Wiktionary Dictionary Import'
    puts "Path: #{path}"
    puts "Limit: #{limit || 'full file'}"
    puts '=' * 80

    begin
      result = VerifyWiktionaryDictionaryImportService.new(path: path, limit: limit).call
    rescue VerifyWiktionaryDictionaryImportService::Error => e
      puts "✗ #{e.message}"
      exit 1
    end

    puts ""
    puts "File lines: #{result[:file_line_count]}"
    puts "DB rows: #{result[:db_count]}"
    puts "Matched: #{result[:matched]}"
    puts "Content mismatches: #{result[:content_mismatch]}"
    puts "SHA mismatches: #{result[:sha_mismatch]}"
    puts "Missing in DB: #{result[:missing_in_db]}"
    puts "Extracted field mismatches: #{result[:field_mismatch]}"
    puts "Extra in DB: #{result[:extra_in_db]}"
    puts "Count mismatch: #{result[:count_mismatch]}"

    if result[:sample_mismatches].any?
      puts ""
      puts "Sample mismatches:"
      result[:sample_mismatches].each { |m| puts "  - #{m.inspect}" }
    end

    puts ""
    if result[:perfect]
      puts "PASS: letter-exact match for all #{result[:matched]} entries"
    else
      puts 'FAIL: file and DB do not match perfectly'
      exit 1
    end
  end
end
