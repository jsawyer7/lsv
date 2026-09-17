# Imports Old Testament token files from app/admin/books/OT into text_contents.
#
# File line format (one token per line):
#   {file_book_number}.{chapter}.{verse} {token}
#
# Verses are rebuilt by joining tokens in file order with single spaces.
# Book association is an explicit filename → books.code map (see FILE_BOOK_MAP).
class ImportOtTokenFilesService
  OT_DIR = Rails.root.join('app/admin/books/OT')

  # Explicit association: filename → destination book code(s).
  # Verified against DB book codes and Swete/Rahlfs file numbering.
  FILE_BOOK_MAP = {
    '01.Genesis.txt' => { book_code: 'GEN' },
    '02.Exodus.txt' => { book_code: 'EXO' },
    '03.Leviticus.txt' => { book_code: 'LEV' },
    '04.Numeri.txt' => { book_code: 'NUM' },
    '05.Deuteronomium.txt' => { book_code: 'DEU' },
    '06.Josue.txt' => { book_code: 'JOS' },
    '08.Judices.txt' => { book_code: 'JUG' },
    '10.Ruth.txt' => { book_code: 'RUT' },
    '11.Regnorum_I.txt' => { book_code: '1SA' },
    '12.Regnorum_II.txt' => { book_code: '2SA' },
    '13.Regnorum_III.txt' => { book_code: '1KI' },
    '14.Regnorum_IV.txt' => { book_code: '2KI' },
    '15.Paralipomenon_I.txt' => { book_code: '1CH' },
    '16.Paralipomenon_II.txt' => { book_code: '2CH' },
    '17.Esdras_A.txt' => { book_code: '1ES' },
    # Esdras B = Ezra–Nehemiah continuous chs 1–23 in Swete
    '18.Esdras_B.txt' => { split: :ezra_nehemiah },
    '19.Esther.txt' => { book_code: 'EST' },
    '20.Judith.txt' => { book_code: 'JDT' },
    '21.Tobias.txt' => { book_code: 'TOB' },
    '23.Machabaeorum_i.txt' => { book_code: '1MA' },
    '24.Machabaeorum_ii.txt' => { book_code: '2MA' },
    '25.Machabaeorum_iii.txt' => { book_code: '3MA' },
    '26.Machabaeorum_iv.txt' => { book_code: '4MA' },
    '27.Psalmi.txt' => { book_code: 'PSA' },
    '28.Odae.txt' => { book_code: 'ODA', ensure_book: { code: 'ODA', std_name: 'Odes', description: 'Book of Odes (LXX / Swete)' } },
    '29.Proverbia.txt' => { book_code: 'PRO' },
    '31.Canticum.txt' => { book_code: 'SNG' },
    '32.Job.txt' => { book_code: 'JOB' },
    '33.Sapientia_Salomonis.txt' => { book_code: 'WIS' },
    '34.Ecclesiasticus.txt' => { book_code: 'SIR' },
    '35.Psalmi_Salomonis.txt' => { book_code: 'PSSOL' },
    '36.Osee.txt' => { book_code: 'HOS' },
    '37.Amos.txt' => { book_code: 'AMO' },
    '38.Michaeas.txt' => { book_code: 'MIC' },
    '39.Joel.txt' => { book_code: 'JOL' },
    '40.Abdias.txt' => { book_code: 'OBA' },
    '41.Jonas.txt' => { book_code: 'JON' },
    '42.Nahum.txt' => { book_code: 'NAH' },
    '43.Habacuc.txt' => { book_code: 'HAB' },
    '44.Sophonias.txt' => { book_code: 'ZEP' },
    '45.Aggaeus.txt' => { book_code: 'HAG' },
    '46.Zacharias.txt' => { book_code: 'ZEC' },
    '47.Malachias.txt' => { book_code: 'MAL' },
    '48.Isaias.txt' => { book_code: 'ISA' },
    '49.Jeremias.txt' => { book_code: 'JER' },
    '50.Baruch.txt' => { book_code: 'BAR' },
    '51.Threni_seu_Lamentationes.txt' => { book_code: 'LAM' },
    '52.Epistula_Jeremiae.txt' => { book_code: 'LETJER' },
    '53.Ezechiel.txt' => { book_code: 'EZK' },
    # Old Greek Daniel family (matches prior DAN≈Susanna/Bel as ch 13–14 convention)
    '56.Daniel_translatio_Graeca.txt' => { book_code: 'DAN' },
    '54.Susanna_translatio_Graeca.txt' => { book_code: 'DAN', remap_chapter: { '1' => 13 } },
    '58.Bel_et_Draco_translatio_Graeca.txt' => { book_code: 'DAN', remap_chapter: { '1' => 14 } },
    # Theodotion Daniel family
    '57.Daniel_Theodotionis_versio.txt' => {
      book_code: 'DANTH',
      ensure_book: { code: 'DANTH', std_name: 'Daniel (Theodotion)', description: 'Daniel according to Theodotion (Swete)' }
    },
    '55.Susanna_Theodotionis_versio.txt' => {
      book_code: 'DANTH',
      remap_chapter: { '1' => 13 },
      ensure_book: { code: 'DANTH', std_name: 'Daniel (Theodotion)', description: 'Daniel according to Theodotion (Swete)' }
    },
    '59.Bel_et_Draco_Theodotionis_versio.txt' => {
      book_code: 'DANTH',
      remap_chapter: { '1' => 14 },
      ensure_book: { code: 'DANTH', std_name: 'Daniel (Theodotion)', description: 'Daniel according to Theodotion (Swete)' }
    }
  }.freeze

  LINE_RE = /\A(\d+)\.([^.]+)\.(\S+)\s+(.+)\z/

  class Error < StandardError; end

  def initialize(source_code: 'LXX_SWETE', dry_run: true, filenames: nil)
    @source_code = source_code
    @dry_run = dry_run
    @filenames = filenames
    @errors = []
    @warnings = []
  end

  def call
    source = resolve_source!
    text_unit_type = source.text_unit_type || TextUnitType.unscoped.find_by(code: 'BIB_VERSE')
    language = source.language
    raise Error, 'Missing text_unit_type (BIB_VERSE) or source language' unless text_unit_type && language

    files = selected_files
    raise Error, "No OT token files found in #{OT_DIR}" if files.empty?

    ensure_required_books!(files)

    verse_rows = []
    file_summaries = []

    files.each do |path|
      summary, rows = parse_file(path, source: source, text_unit_type: text_unit_type, language: language)
      file_summaries << summary
      verse_rows.concat(rows)
    end

    # Detect duplicate unit_keys across files before writing
    dup_keys = verse_rows.group_by { |r| r[:unit_key] }.select { |_k, v| v.size > 1 }.keys
    if dup_keys.any?
      @errors << "Duplicate unit_keys generated: #{dup_keys.first(20).join(', ')}"
    end

    created = 0
    unless @dry_run || @errors.any?
      created = insert_rows!(verse_rows)
    end

    {
      dry_run: @dry_run,
      source: source,
      files_processed: file_summaries.size,
      verses_parsed: verse_rows.size,
      created_count: created,
      would_create: @dry_run ? verse_rows.size : 0,
      file_summaries: file_summaries,
      errors: @errors,
      warnings: @warnings,
      verified: !@dry_run && @errors.empty? && verify_import!(source, verse_rows)
    }
  end

  private

  def resolve_source!
    source = Source.unscoped.find_by(code: @source_code)
    raise Error, "Source not found: #{@source_code}" unless source
    source
  end

  def selected_files
    all = Dir.children(OT_DIR).select { |n| n.end_with?('.txt') }.sort
    names = if @filenames.present?
              Array(@filenames)
            else
              all
            end

    unknown = names - FILE_BOOK_MAP.keys
    missing_map = FILE_BOOK_MAP.keys - all
    @warnings << "Files on disk with no map entry (skipped): #{unknown.join(', ')}" if unknown.any?
    @warnings << "Mapped files missing on disk: #{missing_map.join(', ')}" if missing_map.any?

    names.select { |n| FILE_BOOK_MAP.key?(n) }.map { |n| OT_DIR.join(n) }
  end

  def ensure_required_books!(files)
    codes = []
    files.each do |path|
      cfg = FILE_BOOK_MAP.fetch(path.basename.to_s)
      if cfg[:split] == :ezra_nehemiah
        codes.concat(%w[EZR NEH])
      else
        if cfg[:ensure_book]
          Book.unscoped.find_or_create_by!(code: cfg[:ensure_book][:code]) do |b|
            b.std_name = cfg[:ensure_book][:std_name]
            b.description = cfg[:ensure_book][:description]
          end
        end
        codes << cfg[:book_code]
      end
    end

    codes.uniq.each do |code|
      next if Book.unscoped.exists?(code: code)
      @errors << "Book code missing in DB: #{code}"
    end
    raise Error, @errors.join('; ') if @errors.any?
  end

  def parse_file(path, source:, text_unit_type:, language:)
    filename = path.basename.to_s
    cfg = FILE_BOOK_MAP.fetch(filename)
    expected_book_num = filename.split('.', 2).first.to_i

    # key: [book_code, unit_group, unit] => tokens[]
    buckets = Hash.new { |h, k| h[k] = [] }
    bad_lines = 0
    token_count = 0

    File.foreach(path, encoding: 'UTF-8') do |raw|
      line = raw.rstrip
      next if line.empty?

      m = LINE_RE.match(line)
      unless m
        bad_lines += 1
        @errors << "#{filename}: unparseable line: #{line[0, 120]}" if bad_lines <= 5
        next
      end

      file_book_num, file_chapter, file_verse, token = m.captures
      if file_book_num.to_i != expected_book_num
        bad_lines += 1
        @errors << "#{filename}: book number mismatch got #{file_book_num} expected #{expected_book_num}" if bad_lines <= 5
        next
      end

      destinations = resolve_destinations(cfg, file_chapter, file_verse)
      destinations.each do |book_code, unit_group, unit|
        buckets[[book_code, unit_group, unit]] << token
      end
      token_count += 1
    end

    now = Time.current
    rows = []
    book_codes_used = Set.new
    buckets.each do |(book_code, unit_group, unit), tokens|
      book = Book.unscoped.find_by!(code: book_code)
      book_codes_used << book_code
      content = tokens.join(' ')
      unit_key = "#{source.code}|#{book.code}|#{unit_group}|#{unit}"

      rows << {
        source_id: source.id,
        book_id: book.id,
        text_unit_type_id: text_unit_type.id,
        language_id: language.id,
        unit_group: unit_group,
        unit: unit.to_s,
        unit_key: unit_key,
        content: content,
        word_for_word_translation: [],
        lsv_literal_reconstruction: nil,
        addressed_party_code: nil,
        addressed_party_custom_name: nil,
        responsible_party_code: nil,
        responsible_party_custom_name: nil,
        genre_code: nil,
        population_status: 'pending',
        created_at: now,
        updated_at: now
      }
    end

    # Keep stable order: book, chapter, verse-as-string natural-ish
    rows.sort_by! { |r| [r[:book_id], r[:unit_group], r[:unit].to_s] }

    summary = {
      file: filename,
      tokens: token_count,
      verses: rows.size,
      bad_lines: bad_lines,
      books: book_codes_used.to_a.sort
    }

    @errors << "#{filename}: produced zero verses" if rows.empty?
    [summary, rows]
  end

  # Returns array of [book_code, unit_group(Integer), unit(String)]
  def resolve_destinations(cfg, file_chapter, file_verse)
    if cfg[:split] == :ezra_nehemiah
      ch = Integer(file_chapter)
      if ch <= 10
        return [['EZR', ch, file_verse]]
      elsif ch <= 23
        return [['NEH', ch - 10, file_verse]]
      else
        @errors << "Esdras_B unexpected chapter #{file_chapter}"
        return []
      end
    end

    book_code = cfg[:book_code]
    unit_group, unit = encode_chapter_verse(file_chapter, file_verse, cfg)
    [[book_code, unit_group, unit]]
  end

  def encode_chapter_verse(file_chapter, file_verse, cfg)
    # Chapter remaps (Susanna/Bel → Daniel 13/14)
    if cfg[:remap_chapter] && cfg[:remap_chapter].key?(file_chapter)
      return [cfg[:remap_chapter][file_chapter], file_verse]
    end

    case file_chapter
    when /\A\d+\z/
      [file_chapter.to_i, file_verse]
    when 'prologue'
      # Esther preface: store as chapter 0
      [0, file_verse]
    when 'iva'
      # Odes 4a — keep distinct from 4b via unit prefix
      [4, "a.#{file_verse}"]
    when 'ivb'
      [4, "b.#{file_verse}"]
    else
      @errors << "Unsupported chapter label: #{file_chapter}"
      [0, "#{file_chapter}.#{file_verse}"]
    end
  end

  def insert_rows!(rows)
    created = 0
    rows.each_slice(500) do |batch|
      # insert_all skips validations/callbacks — preserves exact file token text
      result = TextContent.insert_all(batch, record_timestamps: false)
      created += result.length
    end
    created
  end

  def verify_import!(source, expected_rows)
    db_count = TextContent.unscoped.where(source_id: source.id).count
    if db_count != expected_rows.size
      @errors << "Verify failed: DB has #{db_count} rows, expected #{expected_rows.size}"
      return false
    end

    # Spot-check a sample of unit_keys/content against what we parsed
    sample = expected_rows.select { |r| r[:unit_key].include?('|GEN|1|1') || r[:unit_key].include?('|OBA|1|0') || r[:unit_key].include?('|EST|0|1') }
    sample = expected_rows.first(5) if sample.empty?

    sample.each do |row|
      tc = TextContent.unscoped.find_by(unit_key: row[:unit_key], source_id: source.id)
      unless tc
        @errors << "Verify missing unit_key #{row[:unit_key]}"
        return false
      end
      if tc.content != row[:content]
        @errors << "Verify content mismatch for #{row[:unit_key]}"
        return false
      end
    end

    true
  end
end
