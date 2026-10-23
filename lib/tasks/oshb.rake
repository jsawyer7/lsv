namespace :oshb do
  desc "Import OSHB Hebrew OT (WLC) XML from app/admin/books/Herbew OT (no AI). DRY_RUN=true by default. " \
       "LIVE: DRY_RUN=false rake oshb:import. Options: REPLACE=true (re-import), FILES=Gen.xml,Exod.xml"
  task import: :environment do
    dry_run = ENV['DRY_RUN'] != 'false'
    replace = ENV['REPLACE'] == 'true'
    filenames = ENV['FILES'].to_s.split(',').map(&:strip).reject(&:empty?).presence

    puts "=" * 80
    puts "Import OSHB Hebrew OT (WLC) → text_contents + text_content_tokens"
    puts "Mode: #{dry_run ? 'DRY RUN (no changes)' : 'LIVE (will INSERT records)'}#{replace ? ' + REPLACE' : ''}"
    puts "Directory: #{ImportOshbService::OT_DIR}"
    puts "Files: #{filenames ? filenames.join(', ') : 'all'}"
    puts "=" * 80
    puts ""

    begin
      result = ImportOshbService.new(dry_run: dry_run, replace: replace, filenames: filenames).call
    rescue ImportOshbService::Error => e
      puts "✗ #{e.message}"
      exit 1
    end

    puts "Source: #{result[:source_code]} (#{result[:source_exists] ? 'exists' : 'will be created'})"
    puts "Existing rows for these books: #{result[:existing_rows]}"
    puts "Files processed: #{result[:files_processed]}"
    puts "Verses parsed: #{result[:verses_parsed]}"
    puts "Tokens parsed: #{result[:tokens_parsed]} (#{result[:token_kinds].map { |k, n| "#{k}=#{n}" }.join(', ')})"
    puts ""
    puts "Per-file summary:"
    result[:file_summaries].each do |s|
      puts "  - #{s[:file].ljust(10)} → #{s[:book_code].ljust(4)} chapters=#{s[:chapters]} verses=#{s[:verses]} tokens=#{s[:tokens]}"
    end

    if result[:warnings].any?
      puts ""
      puts "Warnings:"
      result[:warnings].each { |w| puts "  - #{w}" }
    end

    if result[:errors].any?
      puts ""
      puts "Errors:"
      result[:errors].first(30).each { |e| puts "  - #{e}" }
      puts "  ... (#{result[:errors].size} total)" if result[:errors].size > 30
      puts ""
      puts dry_run ? "✗ Fix the errors above before importing." : "✗ Import rolled back; nothing was written."
      exit 1
    end

    puts ""
    if result[:dry_run]
      puts "DRY RUN: would create #{result[:verses_parsed]} verse(s) and #{result[:tokens_parsed]} token(s)."
      puts "To import for real:"
      puts "  DRY_RUN=false rake oshb:import#{result[:existing_rows].positive? ? ' REPLACE=true' : ''}"
    else
      puts "Created verses: #{result[:created_verses]}"
      puts "Created tokens: #{result[:created_tokens]}"
      puts "✓ Import verified: every verse and token matches the files exactly."
    end

    puts ""
    puts "Done!"
  end
end
