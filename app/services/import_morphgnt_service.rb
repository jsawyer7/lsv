# Imports the MorphGNT SBLGNT files from app/admin/books/NT into
#   - text_contents        one row per verse (content = words joined by spaces)
#   - text_content_tokens  one row per word, verbatim from the file
#   - canonical_source_texts  gold-master verse text for fidelity checks
#
# Deterministic file import only: nothing here calls or prepares data for AI.
# Rows get population_status 'source_import' and the source is listed in
# TextContent::AI_LOCKED_SOURCE_CODES, so the AI population pipeline skips them.
#
# File line format (7 space-separated columns, one word per line):
#   BBCCVV POS PARSING TEXT WORD NORMALIZED LEMMA
#   010101 N- ----NSF- Βίβλος Βίβλος βίβλος βίβλος
#
# TEXT carries SBLGNT apparatus signs (⸀ ⸁ ⸂ ⸃ ⸄ ⸅, sometimes numbered: ⸀1).
# They are stripped from the verse content but kept in tokens.surface.
# Editorial brackets ⟦ ⟧ and [ ] are part of the text and are kept.
class ImportMorphgntService
  NT_DIR = Rails.root.join('app/admin/books/NT')

  SOURCE_ATTRIBUTES = {
    code: 'GRK_SBLGNT',
    name: 'SBL Greek New Testament (MorphGNT)',
    description: 'SBL Greek New Testament (2010) with MorphGNT morphological tagging and lemmatization.',
    provenance: 'MorphGNT SBLGNT files (https://github.com/morphgnt/sblgnt), imported verbatim by ImportMorphgntService.',
    rights_json: {
      'text' => 'SBLGNT — Society of Biblical Literature and Logos Bible Software. See https://sblgnt.com/license/',
      'morphology' => 'MorphGNT — see https://github.com/morphgnt/sblgnt for license terms'
    }
  }.freeze

  # Explicit association: filename → books.code (book number BB in the file must match).
  FILE_BOOK_MAP = {
    '61-Mt-morphgnt.txt' => { book_number: 1, book_code: 'MAT' },
    '62-Mk-morphgnt.txt' => { book_number: 2, book_code: 'MRK' },
    '63-Lk-morphgnt.txt' => { book_number: 3, book_code: 'LUK' },
    '64-Jn-morphgnt.txt' => { book_number: 4, book_code: 'JOH' },
    '65-Ac-morphgnt.txt' => { book_number: 5, book_code: 'ACT' },
    '66-Ro-morphgnt.txt' => { book_number: 6, book_code: 'ROM' },
    '67-1Co-morphgnt.txt' => { book_number: 7, book_code: '1CO' },
    '68-2Co-morphgnt.txt' => { book_number: 8, book_code: '2CO' },
    '69-Ga-morphgnt.txt' => { book_number: 9, book_code: 'GAL' },
    '70-Eph-morphgnt.txt' => { book_number: 10, book_code: 'EPH' },
    '71-Php-morphgnt.txt' => { book_number: 11, book_code: 'PHP' },
    '72-Col-morphgnt.txt' => { book_number: 12, book_code: 'COL' },
    '73-1Th-morphgnt.txt' => { book_number: 13, book_code: '1TH' },
    '74-2Th-morphgnt.txt' => { book_number: 14, book_code: '2TH' },
    '75-1Ti-morphgnt.txt' => { book_number: 15, book_code: '1TI' },
    '76-2Ti-morphgnt.txt' => { book_number: 16, book_code: '2TI' },
    '77-Tit-morphgnt.txt' => { book_number: 17, book_code: 'TIT' },
    '78-Phm-morphgnt.txt' => { book_number: 18, book_code: 'PHM' },
    '79-Heb-morphgnt.txt' => { book_number: 19, book_code: 'HEB' },
    '80-Jas-morphgnt.txt' => { book_number: 20, book_code: 'JAS' },
    '81-1Pe-morphgnt.txt' => { book_number: 21, book_code: '1PE' },
    '82-2Pe-morphgnt.txt' => { book_number: 22, book_code: '2PE' },
    '83-1Jn-morphgnt.txt' => { book_number: 23, book_code: '1JN' },
    '84-2Jn-morphgnt.txt' => { book_number: 24, book_code: '2JN' },
    '85-3Jn-morphgnt.txt' => { book_number: 25, book_code: '3JN' },
    '86-Jud-morphgnt.txt' => { book_number: 26, book_code: 'JUD' },
    '87-Re-morphgnt.txt' => { book_number: 27, book_code: 'REV' }
  }.freeze

  REF_RE = /\A(\d{2})(\d{2})(\d{2})\z/
  # ⸀/⸁ may carry an occurrence index when a verse has several (⸀1, ⸀2).
  APPARATUS_SIGNS_RE = /[⸀⸁]\d*|[⸂⸃⸄⸅]/
  BATCH_SIZE = 1000

  # Spot checks run after import (unit "book|chapter|verse" => expectation).
  SPOT_CHECKS = {
    'MAT|1|1' => 'Βίβλος γενέσεως Ἰησοῦ χριστοῦ υἱοῦ Δαυὶδ υἱοῦ Ἀβραάμ.',
    'MRK|16|9' => /\A⟦Ἀναστὰς δὲ/,
    'JOH|7|53' => :absent
  }.freeze

  class Error < StandardError; end

  Verse = Struct.new(:book_code, :chapter, :verse, :tokens, keyword_init: true) do
    def unit_key(source_code) = "#{source_code}|#{book_code}|#{chapter}|#{verse}"

    def content = tokens.map { |t| t[:surface].gsub(APPARATUS_SIGNS_RE, '') }.reject(&:empty?).join(' ')
  end

  def initialize(dry_run: true, replace: false, filenames: nil, dir: NT_DIR)
    @dir = Pathname(dir)
    @dry_run = dry_run
    @replace = replace
    @filenames = filenames
    @errors = []
    @warnings = []
  end

  def call
    files = selected_files
    raise Error, "No MorphGNT files found in #{@dir}" if files.empty?

    books = resolve_books!(files)
    file_summaries = []
    verses = []

    files.each do |path|
      summary, file_verses = parse_file(path)
      file_summaries << summary
      verses.concat(file_verses)
    end

    check_parsed!(verses)
    resolve_reference_data!

    source = Source.unscoped.find_by(code: SOURCE_ATTRIBUTES[:code])
    check_existing_source!(source)
    book_ids = books.values.map(&:id)
    existing = source ? TextContent.unscoped.where(source_id: source.id, book_id: book_ids).count : 0
    if existing.positive? && !@replace
      @errors << "#{SOURCE_ATTRIBUTES[:code]} already has #{existing} text_contents row(s). Re-run with REPLACE=true to delete and re-import them."
    end

    result = {
      dry_run: @dry_run,
      source_code: SOURCE_ATTRIBUTES[:code],
      source_exists: source.present?,
      existing_rows: existing,
      files_processed: file_summaries.size,
      verses_parsed: verses.size,
      tokens_parsed: verses.sum { |v| v.tokens.size },
      file_summaries: file_summaries,
      created_verses: 0,
      created_tokens: 0,
      verified: false
    }

    unless @dry_run || @errors.any?
      # requires_new: a savepoint, so the Rollback below also works when called inside another transaction.
      ActiveRecord::Base.transaction(requires_new: true) do
        source = ensure_source!
        delete_existing!(source, books) if existing.positive?
        result[:created_verses], result[:created_tokens] = insert_verses!(source, books, verses)
        result[:verified] = verify_import!(source, books, verses)
        # Never leave a partial or unverified import behind.
        raise ActiveRecord::Rollback unless result[:verified]
      end
      if result[:verified]
        result[:source_exists] = true
      else
        result[:created_verses] = result[:created_tokens] = 0
      end
    end

    result.merge(errors: @errors, warnings: @warnings)
  end

  private

  def selected_files
    on_disk = Dir.exist?(@dir) ? Dir.children(@dir).select { |n| n.end_with?('-morphgnt.txt') }.sort : []
    names = @filenames.present? ? Array(@filenames) : on_disk

    unmapped = names - FILE_BOOK_MAP.keys
    @warnings << "Files with no map entry (skipped): #{unmapped.join(', ')}" if unmapped.any?
    missing = (@filenames.present? ? names & FILE_BOOK_MAP.keys : FILE_BOOK_MAP.keys) - on_disk
    @errors << "Mapped files missing on disk: #{missing.join(', ')}" if missing.any?

    (names & FILE_BOOK_MAP.keys & on_disk).map { |n| @dir.join(n) }
  end

  def resolve_books!(files)
    codes = files.map { |p| FILE_BOOK_MAP.fetch(p.basename.to_s)[:book_code] }
    books = Book.unscoped.where(code: codes).index_by(&:code)
    missing = codes - books.keys
    raise Error, "Book code(s) missing in DB: #{missing.join(', ')}" if missing.any?

    books
  end

  def parse_file(path)
    filename = path.basename.to_s
    cfg = FILE_BOOK_MAP.fetch(filename)
    verses = {}
    bad_lines = 0
    prev_ref = nil

    File.foreach(path, encoding: 'UTF-8').with_index(1) do |raw, line_no|
      line = raw.chomp
      next if line.empty?

      fields = line.split(' ', -1)
      ref = fields[0]
      m = REF_RE.match(ref.to_s)
      problem = if fields.size != 7 || fields.any?(&:empty?)
                  "expected 7 non-empty fields, got #{fields.size}"
                elsif !m
                  "bad reference #{ref.inspect}"
                elsif m[1].to_i != cfg[:book_number]
                  "book number #{m[1]} does not match file (expected #{format('%02d', cfg[:book_number])})"
                elsif prev_ref && ref < prev_ref
                  "reference #{ref} is out of order (after #{prev_ref})"
                elsif !line.valid_encoding?
                  'invalid UTF-8'
                end

      if problem
        bad_lines += 1
        @errors << "#{filename}:#{line_no}: #{problem}: #{line[0, 120]}" if bad_lines <= 5
        next
      end

      prev_ref = ref
      _ref, pos, parsing, surface, word, normalized, lemma = fields
      verse = verses[ref] ||= Verse.new(book_code: cfg[:book_code], chapter: m[2].to_i, verse: m[3].to_i, tokens: [])
      verse.tokens << {
        position: verse.tokens.size + 1, ref: ref, pos: pos, parsing: parsing,
        surface: surface, word: word, normalized: normalized, lemma: lemma
      }
    end

    @errors << "#{filename}: #{bad_lines} bad line(s)" if bad_lines > 5
    @errors << "#{filename}: produced zero verses" if verses.empty?

    summary = {
      file: filename,
      book_code: cfg[:book_code],
      tokens: verses.values.sum { |v| v.tokens.size },
      verses: verses.size,
      chapters: verses.values.map(&:chapter).uniq.size,
      bad_lines: bad_lines
    }
    [summary, verses.values]
  end

  def check_parsed!(verses)
    dups = verses.group_by { |v| v.unit_key(SOURCE_ATTRIBUTES[:code]) }.select { |_k, v| v.size > 1 }.keys
    @errors << "Duplicate verses: #{dups.first(20).join(', ')}" if dups.any?

    verses.each do |v|
      stray = v.content[/\d|[⸀-⸅]/]
      @errors << "#{v.book_code} #{v.chapter}:#{v.verse}: leftover apparatus character #{stray.inspect} in content" if stray
      @errors << "#{v.book_code} #{v.chapter}:#{v.verse}: empty content" if v.content.empty?
    end
  end

  # Rows always use these explicitly resolved ids, never whatever an existing
  # source row happens to hold (ids differ between environments).
  def resolve_reference_data!
    @language = Language.unscoped.find_by(code: 'grc') or raise Error, 'Language grc (Greek) missing'
    @unit_type = TextUnitType.unscoped.find_by(code: 'BIB_VERSE') or raise Error, 'TextUnitType BIB_VERSE missing'
  end

  # A GRK_SBLGNT source may already exist (e.g. created by hand in admin).
  # Checked during dry runs too, so a bad source is reported before any write.
  def check_existing_source!(source)
    return unless source

    if source.language_id != @language.id
      actual = Language.unscoped.find_by(id: source.language_id)&.code || 'none'
      @errors << "Existing source #{source.code} (id #{source.id}) has language #{actual}, expected grc. Fix it in admin before importing."
    end

    if source.text_unit_type_id.nil?
      @warnings << "Existing source #{source.code} (id #{source.id}) has no text unit type; it will be set to BIB_VERSE."
    elsif source.text_unit_type_id != @unit_type.id
      actual = TextUnitType.unscoped.find_by(id: source.text_unit_type_id)&.code
      @errors << "Existing source #{source.code} (id #{source.id}) has text unit type #{actual}, expected BIB_VERSE. Fix it in admin before importing."
    end
  end

  def ensure_source!
    source = Source.unscoped.find_or_create_by!(code: SOURCE_ATTRIBUTES[:code]) do |s|
      s.assign_attributes(SOURCE_ATTRIBUTES.except(:code))
      s.language = @language
      s.text_unit_type = @unit_type
    end
    source.update!(text_unit_type: @unit_type) if source.text_unit_type_id.nil?
    source
  end

  # Only the books being imported, so a FILES=... run never touches other books.
  def delete_existing!(source, books)
    scope = TextContent.unscoped.where(source_id: source.id, book_id: books.values.map(&:id))
    ids = scope.select(:id)
    TextContentToken.unscoped.where(text_content_id: ids).delete_all
    CanonTextContent.where(text_content_id: ids).delete_all
    TextTranslation.unscoped.where(text_content_id: ids).delete_all
    scope.delete_all
    CanonicalSourceText.where(source_code: source.code, book_code: books.keys).delete_all
  end

  def insert_verses!(source, books, verses)
    now = Time.current
    created_verses = 0
    created_tokens = 0

    verses.each_slice(BATCH_SIZE) do |batch|
      verse_rows = batch.map do |v|
        {
          source_id: source.id,
          book_id: books.fetch(v.book_code).id,
          text_unit_type_id: @unit_type.id,
          language_id: @language.id,
          unit_group: v.chapter,
          unit: v.verse.to_s,
          unit_key: v.unit_key(source.code),
          content: v.content,
          word_for_word_translation: [],
          population_status: TextContent::SOURCE_IMPORT_STATUS,
          created_at: now,
          updated_at: now
        }
      end

      # insert_all skips TextContent's normalize callback, so content is stored exactly as rebuilt.
      ids = TextContent.insert_all!(verse_rows, returning: %w[id unit_key]).rows.to_h { |id, key| [key, id] }
      created_verses += ids.size

      token_rows = batch.flat_map do |v|
        tc_id = ids.fetch(v.unit_key(source.code))
        v.tokens.map { |t| t.merge(text_content_id: tc_id, created_at: now, updated_at: now) }
      end
      token_rows.each_slice(BATCH_SIZE * 5) { |rows| created_tokens += TextContentToken.insert_all!(rows).length }

      CanonicalSourceText.insert_all!(batch.map do |v|
        {
          source_code: source.code, book_code: v.book_code, chapter_number: v.chapter,
          verse_number: v.verse.to_s, canonical_text: v.content, created_at: now, updated_at: now
        }
      end)
    end

    [created_verses, created_tokens]
  end

  # Re-reads everything from the DB and compares it against the parsed files:
  # every verse's content and every token's 7 fields must match exactly.
  def verify_import!(source, books, verses)
    book_codes = books.values.to_h { |b| [b.id, b.code] }
    expected = verses.to_h { |v| [v.unit_key(source.code), v] }

    db_verses = TextContent.unscoped.where(source_id: source.id, book_id: books.values.map(&:id)).pluck(:id, :unit_key, :content, :book_id, :population_status, :language_id, :text_unit_type_id)
    if db_verses.size != expected.size
      @errors << "Verify: DB has #{db_verses.size} verses, expected #{expected.size}"
      return false
    end

    key_by_id = {}
    db_verses.each do |id, key, content, book_id, status, language_id, unit_type_id|
      v = expected[key]
      problem = if v.nil? then 'unexpected verse'
                elsif content != v.content then 'content mismatch'
                elsif book_codes[book_id] != v.book_code then 'wrong book'
                elsif status != TextContent::SOURCE_IMPORT_STATUS then "status #{status}"
                elsif language_id != @language.id then 'wrong language'
                elsif unit_type_id != @unit_type.id then 'wrong text unit type'
                end
      if problem
        @errors << "Verify: #{key}: #{problem}"
        return false
      end
      key_by_id[id] = key
    end

    fields = %i[position ref pos parsing surface word normalized lemma]
    db_tokens = Hash.new { |h, k| h[k] = [] }
    TextContentToken.unscoped.where(text_content_id: key_by_id.keys)
                    .order(:text_content_id, :position)
                    .pluck(:text_content_id, *fields)
                    .each { |tc_id, *vals| db_tokens[key_by_id[tc_id]] << fields.zip(vals).to_h }

    expected.each do |key, v|
      next if db_tokens[key] == v.tokens.map { |t| t.slice(*fields) }

      @errors << "Verify: #{key}: tokens differ from file"
      return false
    end

    canonical = CanonicalSourceText.where(source_code: source.code, book_code: books.keys).count
    if canonical != expected.size
      @errors << "Verify: canonical_source_texts has #{canonical} rows, expected #{expected.size}"
      return false
    end

    SPOT_CHECKS.each do |unit, expectation|
      next unless books.key?(unit.split('|').first)

      v = expected["#{source.code}|#{unit}"]
      ok = case expectation
           when :absent then v.nil?
           when Regexp then v && v.content.match?(expectation)
           else v && v.content == expectation
           end
      next if ok

      @errors << "Verify: spot check failed for #{unit}"
      return false
    end

    true
  end
end
