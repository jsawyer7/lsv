namespace :morphgnt do
  desc "Import MorphGNT SBLGNT files from app/admin/books/NT (no AI). DRY_RUN=true by default. " \
       "LIVE: DRY_RUN=false rake morphgnt:import. Options: REPLACE=true (re-import), FILES=61-Mt-morphgnt.txt,62-Mk-morphgnt.txt"
  task import: :environment do
    dry_run = ENV['DRY_RUN'] != 'false'
    replace = ENV['REPLACE'] == 'true'
    filenames = ENV['FILES'].to_s.split(',').map(&:strip).reject(&:empty?).presence

    puts "=" * 80
    puts "Import MorphGNT SBLGNT → text_contents + text_content_tokens"
    puts "Mode: #{dry_run ? 'DRY RUN (no changes)' : 'LIVE (will INSERT records)'}#{replace ? ' + REPLACE' : ''}"
    puts "Directory: #{ImportMorphgntService::NT_DIR}"
    puts "Files: #{filenames ? filenames.join(', ') : 'all'}"
    puts "=" * 80
    puts ""

    begin
      result = ImportMorphgntService.new(dry_run: dry_run, replace: replace, filenames: filenames).call
    rescue ImportMorphgntService::Error => e
      puts "✗ #{e.message}"
      exit 1
    end

    puts "Source: #{result[:source_code]} (#{result[:source_exists] ? 'exists' : 'will be created'})"
    puts "Existing rows for these books: #{result[:existing_rows]}"
    puts "Files processed: #{result[:files_processed]}"
    puts "Verses parsed: #{result[:verses_parsed]}"
    puts "Tokens parsed: #{result[:tokens_parsed]}"
    puts ""
    puts "Per-file summary:"
    result[:file_summaries].each do |s|
      puts "  - #{s[:file].ljust(22)} → #{s[:book_code].ljust(4)} chapters=#{s[:chapters]} verses=#{s[:verses]} tokens=#{s[:tokens]} bad_lines=#{s[:bad_lines]}"
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
      puts "  DRY_RUN=false rake morphgnt:import#{result[:existing_rows].positive? ? ' REPLACE=true' : ''}"
    else
      puts "Created verses: #{result[:created_verses]}"
      puts "Created tokens: #{result[:created_tokens]}"
      puts "✓ Import verified: every verse and token matches the files exactly."
    end

    puts ""
    puts "Done!"
  end
end
