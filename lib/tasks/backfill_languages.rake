namespace :languages do
  desc "Backfill rendering/shaping fields and directions for known languages"
  task backfill_rendering_fields: :environment do
    def find_lang_by_codes(*codes)
      codes.compact.each do |c|
        lang = Language.where('lower(code) = ?', c.to_s.downcase).first
        return lang if lang
      end
      nil
    end

    ltr = Direction.find_by!(code: 'LTR')
    rtl = Direction.find_by!(code: 'RTL')

    updates = [
      {
        codes: %w[grc elx], # primary first, include alternates if any
        attrs: {
          direction: ltr,
          script: 'Greek',
          font_stack: 'SBL Greek, New Athena Unicode, Gentium, serif',
          has_joining: false,
          uses_diacritics: true,
          has_cantillation: false,
          has_ayah_markers: false,
          native_digits: false,
          unicode_normalization: 'NFC',
          shaping_engine: 'HarfBuzz',
          punctuation_mirroring: false
        }
      },
      {
        codes: %w[heb he],
        attrs: {
          direction: rtl,
          script: 'Hebrew',
          font_stack: 'SBL Hebrew, Ezra SIL, Frank Ruehl, serif',
          has_joining: false,
          uses_diacritics: true,
          has_cantillation: true,
          has_ayah_markers: false,
          native_digits: false,
          unicode_normalization: 'NFC',
          shaping_engine: 'HarfBuzz',
          punctuation_mirroring: true
        }
      },
      {
        codes: %w[ara ar],
        attrs: {
          direction: rtl,
          script: 'Arabic',
          font_stack: 'KFGQPC Uthmanic, Scheherazade New, Amiri, serif',
          has_joining: true,
          uses_diacritics: true,
          has_cantillation: false,
          has_ayah_markers: true,
          native_digits: true,
          unicode_normalization: 'NFC',
          shaping_engine: 'HarfBuzz',
          punctuation_mirroring: true
        }
      },
      {
        codes: %w[syr syc],
        attrs: {
          direction: rtl,
          script: 'Syriac',
          font_stack: 'SBL Syriac, Estrangelo Edessa, Meltho, serif',
          has_joining: true,
          uses_diacritics: true,
          has_cantillation: false,
          has_ayah_markers: false,
          native_digits: false,
          unicode_normalization: 'NFC',
          shaping_engine: 'HarfBuzz',
          punctuation_mirroring: true
        }
      },
      {
        codes: %w[gez],
        attrs: {
          direction: ltr,
          script: 'Ethiopic',
          font_stack: 'Abyssinica SIL, Noto Serif Ethiopic, serif',
          has_joining: false,
          uses_diacritics: false,
          has_cantillation: false,
          has_ayah_markers: false,
          native_digits: false,
          unicode_normalization: 'NFC',
          shaping_engine: 'HarfBuzz',
          punctuation_mirroring: false
        }
      },
      {
        codes: %w[eng en],
        attrs: {
          direction: ltr,
          script: 'Latin',
          font_stack: 'Inter, system-ui, Arial, sans-serif',
          has_joining: false,
          uses_diacritics: false,
          has_cantillation: false,
          has_ayah_markers: false,
          native_digits: false,
          unicode_normalization: 'NFC',
          shaping_engine: 'HarfBuzz',
          punctuation_mirroring: false
        }
      },
      {
        codes: %w[hye arm], # support both ISO and colloquial code
        attrs: {
          direction: ltr,
          script: 'Armenian',
          font_stack: 'Noto Serif Armenian, Sylfaen, serif',
          has_joining: false,
          uses_diacritics: true,
          has_cantillation: false,
          has_ayah_markers: false,
          native_digits: false,
          unicode_normalization: 'NFC',
          shaping_engine: 'HarfBuzz',
          punctuation_mirroring: false
        }
      }
    ]

    updated = 0
    skipped = []

    updates.each do |entry|
      lang = find_lang_by_codes(*entry[:codes])
      if lang
        lang.update!(entry[:attrs])
        puts "✓ Updated #{lang.name} (#{lang.code})"
        updated += 1
      else
        skipped << entry[:codes].first
      end
    end

    puts "\nBackfill complete. Updated #{updated} language(s)."
    unless skipped.empty?
      puts "Skipped (not found by code): #{skipped.join(', ')}"
    end
  end
end


