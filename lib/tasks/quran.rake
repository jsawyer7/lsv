namespace :quran do
  desc "Import the Tanzil Qur'an (Uthmani 1.1) XML from app/admin/books/Quran (no AI). DRY_RUN=true by default. " \
       "LIVE: DRY_RUN=false rake quran:import. Options: REPLACE=true (re-import)"
  task import: :environment do
    dry_run = ENV['DRY_RUN'] != 'false'
    replace = ENV['REPLACE'] == 'true'

    puts "=" * 80
    puts "Import Tanzil Qur'an (Uthmani 1.1) → text_contents"
    puts "Mode: #{dry_run ? 'DRY RUN (no changes)' : 'LIVE (will INSERT records)'}#{replace ? ' + REPLACE' : ''}"
    puts "File: #{ImportTanzilQuranService::FILE}"
    puts "=" * 80
    puts ""

    begin
      result = ImportTanzilQuranService.new(dry_run: dry_run, replace: replace).call
    rescue ImportTanzilQuranService::Error => e
      puts "✗ #{e.message}"
      exit 1
    end

    puts "Source: #{result[:source_code]} (#{result[:source_exists] ? 'exists' : 'will be created'})"
    puts "File SHA-256: #{result[:file_sha256]}"
    puts "Existing rows: #{result[:existing_rows]}"
    puts "Surahs parsed: #{result[:surahs_parsed]}"
    puts "Ayahs parsed: #{result[:ayahs_parsed]}"

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
      puts "DRY RUN: would create #{result[:ayahs_parsed]} ayah(s)."
      puts "To import for real:"
      puts "  DRY_RUN=false rake quran:import#{result[:existing_rows].positive? ? ' REPLACE=true' : ''}"
    else
      puts "Created ayahs: #{result[:created_ayahs]}"
      puts "✓ Import verified: every ayah matches the file exactly."
    end

    puts ""
    puts "Done!"
  end
end
