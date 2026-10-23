# Imports the Open Scriptures Hebrew Bible (OSHB = Westminster Leningrad Codex
# 4.20 + morphology, OSIS XML) from app/admin/books/Herbew OT into
#   - text_contents           one row per verse (source MT_WLC)
#   - text_content_tokens     one row per <w> word, incl. ketiv and qere forms
#   - canonical_source_texts  gold-master verse text for fidelity checks
#
# Deterministic file import only: nothing here calls or prepares data for AI.
# MT_WLC is listed in TextContent::AI_LOCKED_SOURCE_CODES and rows get
# population_status 'source_import', so the AI population pipeline skips them.
#
# Verse text is rebuilt from the verse's direct children in file order:
#   <w>    word text with OSHB's morpheme separators "/" removed
#          (ketiv words are direct children, so the written form is used)
#   <seg>  maqqef ־, sof pasuq ׃, paseq ׀, paragraph marks פ / ס, inverted nun ׆
#   <note> skipped (KJV refs, qere readings, accent alternatives, OSHB notes)
# Whitespace in the XML between two pieces becomes one space; no whitespace
# means the pieces are joined (maqqef, sof pasuq, words OSHB split for exegesis).
#
# Text is never Unicode-normalized: ~47% of WLC words are deliberately not NFC
# (mark order), so all strings are stored exactly as they appear in the file.
# The exact original XML of every verse and word is kept in source_xml.
class ImportOshbService
  OT_DIR = Rails.root.join('app/admin/books/Herbew OT')
  SOURCE_CODE = 'MT_WLC'.freeze
  OSIS_NS = { 'osis' => 'http://www.bibletechnologies.net/2003/OSIS/namespace' }.freeze

  SOURCE_ATTRIBUTES = {
    code: SOURCE_CODE,
    name: 'Masoretic Text (Westminster Leningrad Codex)',
    description: 'Westminster Leningrad Codex 4.20 with Open Scriptures Hebrew Bible (OSHB) lemmas and morphology.',
    provenance: 'OSHB OSIS files (https://github.com/openscriptures/morphhb), imported verbatim by ImportOshbService.',
    rights_json: {
      'text' => 'Westminster Leningrad Codex — Public Domain (http://www.tanach.us/Tanach.xml)',
      'morphology' => 'Open Scriptures Hebrew Bible — Creative Commons Attribution 4.0'
    }
  }.freeze

  # Explicit association: filename → OSIS book id in the file → books.code.
  # Note Judges is JUG (JUD is Jude).
  FILE_BOOK_MAP = {
    'Gen.xml' => %w[Gen GEN], 'Exod.xml' => %w[Exod EXO], 'Lev.xml' => %w[Lev LEV],
    'Num.xml' => %w[Num NUM], 'Deut.xml' => %w[Deut DEU], 'Josh.xml' => %w[Josh JOS],
    'Judg.xml' => %w[Judg JUG], 'Ruth.xml' => %w[Ruth RUT], '1Sam.xml' => %w[1Sam 1SA],
    '2Sam.xml' => %w[2Sam 2SA], '1Kgs.xml' => %w[1Kgs 1KI], '2Kgs.xml' => %w[2Kgs 2KI],
    '1Chr.xml' => %w[1Chr 1CH], '2Chr.xml' => %w[2Chr 2CH], 'Ezra.xml' => %w[Ezra EZR],
    'Neh.xml' => %w[Neh NEH], 'Esth.xml' => %w[Esth EST], 'Job.xml' => %w[Job JOB],
    'Ps.xml' => %w[Ps PSA], 'Prov.xml' => %w[Prov PRO], 'Eccl.xml' => %w[Eccl ECC],
    'Song.xml' => %w[Song SNG], 'Isa.xml' => %w[Isa ISA], 'Jer.xml' => %w[Jer JER],
    'Lam.xml' => %w[Lam LAM], 'Ezek.xml' => %w[Ezek EZK], 'Dan.xml' => %w[Dan DAN],
    'Hos.xml' => %w[Hos HOS], 'Joel.xml' => %w[Joel JOL], 'Amos.xml' => %w[Amos AMO],
    'Obad.xml' => %w[Obad OBA], 'Jonah.xml' => %w[Jonah JON], 'Mic.xml' => %w[Mic MIC],
    'Nah.xml' => %w[Nah NAH], 'Hab.xml' => %w[Hab HAB], 'Zeph.xml' => %w[Zeph ZEP],
    'Hag.xml' => %w[Hag HAG], 'Zech.xml' => %w[Zech ZEC], 'Mal.xml' => %w[Mal MAL]
  }.freeze

  # Known non-book files in the folder (WLC↔KJV versification map; not imported).
  IGNORED_FILES = %w[VerseMap.xml].freeze

  # Verse-level <seg> types included in verse text. x-reversednun is the
  # inverted nun ׆ (U+05C6) around Num 10:35–36 and Ps 107.
  SEG_TYPES = %w[x-maqqef x-sof-pasuq x-paseq x-pe x-samekh x-reversednun].freeze
  VERSE_RAW_RE = %r{<verse osisID="([^"]+)">.*?</verse>}m
  WORD_RAW_RE = %r{<w\b[^>]*>.*?</w>}m
  OSIS_ID_RE = /\A([1-3]?[A-Za-z]+)\.(\d+)\.(\d+)\z/
  BATCH_SIZE = 1000

  class Error < StandardError; end

  Verse = Struct.new(:book_code, :osis_id, :chapter, :verse, :content, :source_xml, :tokens, keyword_init: true)

  def initialize(dry_run: true, replace: false, filenames: nil, dir: OT_DIR)
    @dir = Pathname(dir)
    @dry_run = dry_run
    @replace = replace
    @filenames = filenames
    @errors = []
    @warnings = []
  end

  def call
    files = selected_files
    raise Error, "No OSHB book files found in #{@dir}" if files.empty?

    books = resolve_books!(files)

    # Pass 1: parse and check every file, keeping only counts. Files are
    # processed one at a time so memory stays at one book (the whole OT held at
    # once peaked at ~1.3 GB and was killed on a Heroku one-off dyno).
    file_summaries = []
    token_kinds = Hash.new(0)
    files.each do |path|
      summary, verses = parse_file(path)
      check_parsed!(verses)
      verses.each { |v| v.tokens.each { |t| token_kinds[t[:kind]] += 1 } }
      file_summaries << summary
    end

    resolve_reference_data!

    source = Source.unscoped.find_by(code: SOURCE_CODE)
    check_existing_source!(source)
    book_ids = books.values.map(&:id)
    existing = source ? TextContent.unscoped.where(source_id: source.id, book_id: book_ids).count : 0
    if existing.positive? && !@replace
      @errors << "#{SOURCE_CODE} already has #{existing} text_contents row(s) for these books. Re-run with REPLACE=true to delete and re-import them."
    end

    result = {
      dry_run: @dry_run,
      source_code: SOURCE_CODE,
      source_exists: source.present?,
      existing_rows: existing,
      files_processed: file_summaries.size,
      verses_parsed: file_summaries.sum { |s| s[:verses] },
      tokens_parsed: file_summaries.sum { |s| s[:tokens] },
      token_kinds: token_kinds,
      file_summaries: file_summaries,
      created_verses: 0,
      created_tokens: 0,
      verified: false
    }

    unless @dry_run || @errors.any?
      # Pass 2: still one transaction for the whole OT, but each book is parsed,
      # inserted and verified before the next is loaded.
      # requires_new: a savepoint, so the Rollback below also works when called inside another transaction.
      without_sql_logging do
        ActiveRecord::Base.transaction(requires_new: true) do
          source = ensure_source!
          delete_existing!(source, books) if existing.positive?

          verified = files.all? do |path|
            _summary, verses = parse_file(path)
            next false if @errors.any? # file changed since pass 1

            book_code = FILE_BOOK_MAP.fetch(path.basename.to_s).last
            created_verses, created_tokens = insert_verses!(source, books, verses)
            result[:created_verses] += created_verses
            result[:created_tokens] += created_tokens
            verify_import!(source, books.slice(book_code), verses)
          end

          result[:verified] = verified && totals_match?(source, books, result)
          # Never leave a partial or unverified import behind.
          raise ActiveRecord::Rollback unless result[:verified]
        end
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
    on_disk = Dir.exist?(@dir) ? Dir.children(@dir).select { |n| n.end_with?('.xml') }.sort : []
    names = @filenames.present? ? Array(@filenames) : on_disk - IGNORED_FILES

    unmapped = names - FILE_BOOK_MAP.keys
    @warnings << "Files with no map entry (skipped): #{unmapped.join(', ')}" if unmapped.any?
    missing = (@filenames.present? ? names & FILE_BOOK_MAP.keys : FILE_BOOK_MAP.keys) - on_disk
    @errors << "Mapped files missing on disk: #{missing.join(', ')}" if missing.any?

    (names & FILE_BOOK_MAP.keys & on_disk).map { |n| @dir.join(n) }
  end

  def resolve_books!(files)
    codes = files.map { |p| FILE_BOOK_MAP.fetch(p.basename.to_s).last }
    books = Book.unscoped.where(code: codes).index_by(&:code)
    missing = codes - books.keys
    raise Error, "Book code(s) missing in DB: #{missing.join(', ')}" if missing.any?

    books
  end

  def parse_file(path)
    filename = path.basename.to_s
    osis_book, book_code = FILE_BOOK_MAP.fetch(filename)
    summary = { file: filename, book_code: book_code, verses: 0, chapters: 0, tokens: 0 }

    raw = File.binread(path).force_encoding(Encoding::UTF_8)
    unless raw.valid_encoding?
      @errors << "#{filename}: invalid UTF-8"
      return [summary, []]
    end

    doc = Nokogiri::XML(raw) { |config| config.strict.nonet }
    book_div = doc.at_xpath('//osis:div[@type="book"]', OSIS_NS)
    if book_div.nil? || book_div['osisID'] != osis_book
      @errors << "#{filename}: book div is #{book_div&.[]('osisID').inspect}, expected #{osis_book}"
      return [summary, []]
    end

    verse_nodes = doc.xpath('//osis:verse', OSIS_NS)
    raw_verses = raw.to_enum(:scan, VERSE_RAW_RE).map { Regexp.last_match }
    if raw_verses.map { |m| m[1] } != verse_nodes.map { |v| v['osisID'] }
      @errors << "#{filename}: raw <verse> slices do not line up with parsed verses"
      return [summary, []]
    end

    verses = verse_nodes.zip(raw_verses).filter_map do |node, raw_match|
      build_verse(filename, osis_book, book_code, node, raw_match[0])
    end

    summary.merge!(verses: verses.size, chapters: verses.map(&:chapter).uniq.size, tokens: verses.sum { |v| v.tokens.size })
    @errors << "#{filename}: produced zero verses" if verses.empty?
    [summary, verses]
  rescue Nokogiri::XML::SyntaxError => e
    @errors << "#{filename}: XML error: #{e.message}"
    [summary, []]
  end

  def build_verse(filename, osis_book, book_code, node, raw_xml)
    osis_id = node['osisID']
    m = OSIS_ID_RE.match(osis_id.to_s)
    unless m && m[1] == osis_book
      @errors << "#{filename}: verse #{osis_id.inspect} does not belong to #{osis_book}"
      return nil
    end

    content = build_content(filename, osis_id, node)
    tokens = build_tokens(filename, osis_id, node, raw_xml)
    return nil if content.nil? || tokens.nil?

    Verse.new(book_code: book_code, osis_id: osis_id, chapter: m[2].to_i, verse: m[3].to_i,
              content: content, source_xml: raw_xml, tokens: tokens)
  end

  def build_content(filename, osis_id, node)
    out = +''
    pending_space = false

    node.children.each do |child|
      if child.text?
        unless child.content.strip.empty?
          @errors << "#{filename} #{osis_id}: unexpected loose text #{child.content.strip[0, 40].inspect}"
          return nil
        end
        pending_space = true unless child.content.empty?
        next
      end

      piece = case child.name
              when 'w' then child.text.delete('/')
              when 'seg'
                unless SEG_TYPES.include?(child['type'])
                  @errors << "#{filename} #{osis_id}: unknown seg type #{child['type'].inspect}"
                  return nil
                end
                child.text
              when 'note' then nil
              else
                @errors << "#{filename} #{osis_id}: unexpected element <#{child.name}>"
                return nil
              end
      next if piece.nil?

      out << ' ' if pending_space && !out.empty?
      out << piece
      pending_space = false
    end

    out
  end

  def build_tokens(filename, osis_id, node, raw_xml)
    word_nodes = node.xpath('.//osis:w', OSIS_NS)
    raw_words = raw_xml.scan(WORD_RAW_RE)
    if raw_words.size != word_nodes.size
      @errors << "#{filename} #{osis_id}: #{raw_words.size} raw <w> slices vs #{word_nodes.size} parsed words"
      return nil
    end

    word_nodes.zip(raw_words).each_with_index.map do |(w, raw_w), i|
      kind = token_kind(w)
      problem = if kind.nil? then 'word in an unexpected place'
                elsif !raw_w.include?(%(id="#{w['id']}")) then 'raw slice does not match word id'
                elsif [w['lemma'], w['morph'], w['id']].any?(&:blank?) then 'missing lemma/morph/id'
                elsif w.text.empty? then 'empty word'
                end
      if problem
        @errors << "#{filename} #{osis_id}: word #{i + 1} (#{w['id']}): #{problem}"
        return nil
      end

      {
        position: i + 1, ref: osis_id, kind: kind,
        surface: w.text, word: w.text.delete('/'), lemma: w['lemma'], parsing: w['morph'],
        source_word_id: w['id'], source_n: w['n'], source_xml: raw_w
      }
    end
  end

  # 'qere' words sit inside <note type="variant"><rdg type="x-qere">; ketiv
  # words are direct verse children with type="x-ketiv".
  def token_kind(w)
    in_note = w.ancestors.any? { |a| a.name == 'note' }
    if !in_note && w['type'].nil? then 'word'
    elsif !in_note && w['type'] == 'x-ketiv' then 'ketiv'
    elsif in_note && w['type'].nil? && w.parent.name == 'rdg' && w.parent['type'] == 'x-qere' then 'qere'
    end
  end

  def check_parsed!(verses)
    dups = verses.group_by { |v| [v.book_code, v.chapter, v.verse] }.select { |_k, v| v.size > 1 }.keys
    @errors << "Duplicate verses: #{dups.first(20).map { |d| d.join(' ') }.join(', ')}" if dups.any?

    verses.each do |v|
      if v.content.empty?
        @errors << "#{v.osis_id}: empty content"
      elsif v.content.include?('/') || v.content.match?(/\s{2}|\A\s|\s\z|[\t\n\r]/)
        @errors << "#{v.osis_id}: separator or stray whitespace left in content"
      end
    end

    verses.group_by(&:book_code).each do |code, book_verses|
      book_verses.group_by(&:chapter).each do |ch, ch_verses|
        numbers = ch_verses.map(&:verse)
        @errors << "#{code} #{ch}: verse numbering is not 1..#{numbers.max}" unless numbers == (1..numbers.max).to_a
      end
    end
  end

  # Rows always use these explicitly resolved ids, never whatever an existing
  # source row happens to hold (ids differ between environments).
  def resolve_reference_data!
    @language = Language.unscoped.find_by(code: 'heb') or raise Error, 'Language heb (Hebrew) missing'
    @unit_type = TextUnitType.unscoped.find_by(code: 'BIB_VERSE') or raise Error, 'TextUnitType BIB_VERSE missing'
  end

  # MT_WLC may already exist (it does in the admin data). Checked during dry
  # runs too, so a mismatched source is reported before any write.
  def check_existing_source!(source)
    return unless source

    if source.language_id != @language.id
      actual = Language.unscoped.find_by(id: source.language_id)&.code || 'none'
      @errors << "Existing source #{source.code} (id #{source.id}) has language #{actual}, expected heb. Fix it in admin before importing."
    end

    if source.text_unit_type_id.nil?
      @warnings << "Existing source #{source.code} (id #{source.id}) has no text unit type; it will be set to BIB_VERSE."
    elsif source.text_unit_type_id != @unit_type.id
      actual = TextUnitType.unscoped.find_by(id: source.text_unit_type_id)&.code
      @errors << "Existing source #{source.code} (id #{source.id}) has text unit type #{actual}, expected BIB_VERSE. Fix it in admin before importing."
    end
  end

  def ensure_source!
    source = Source.unscoped.find_or_create_by!(code: SOURCE_CODE) do |s|
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

  def unit_key(source, v) = "#{source.code}|#{v.book_code}|#{v.chapter}|#{v.verse}"

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
          unit_key: unit_key(source, v),
          content: v.content,
          source_xml: v.source_xml,
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
        tc_id = ids.fetch(unit_key(source, v))
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

  # Production logs SQL at DEBUG; inserting 300k rows would print ~130 MB of SQL.
  def without_sql_logging
    logger = ActiveRecord::Base.logger
    return yield unless logger

    previous = logger.level
    logger.level = [previous, Logger::INFO].max
    yield
  ensure
    logger.level = previous if logger && previous
  end

  # Final whole-import check after the per-book verification.
  def totals_match?(source, books, result)
    scope = TextContent.unscoped.where(source_id: source.id, book_id: books.values.map(&:id))
    verses = scope.count
    tokens = TextContentToken.unscoped.where(text_content_id: scope.select(:id)).count
    return true if verses == result[:verses_parsed] && tokens == result[:tokens_parsed]

    @errors << "Verify: DB has #{verses} verses / #{tokens} tokens, expected #{result[:verses_parsed]} / #{result[:tokens_parsed]}"
    false
  end

  TOKEN_FIELDS = %i[position ref kind surface word lemma parsing source_word_id source_n source_xml].freeze

  # Re-reads everything from the DB and compares it against the parsed files:
  # every verse's content and XML and every token field must match exactly.
  def verify_import!(source, books, verses)
    book_codes = books.values.to_h { |b| [b.id, b.code] }
    expected = verses.to_h { |v| [unit_key(source, v), v] }

    db_verses = TextContent.unscoped.where(source_id: source.id, book_id: books.values.map(&:id))
                           .pluck(:id, :unit_key, :content, :source_xml, :book_id, :population_status, :language_id, :text_unit_type_id)
    if db_verses.size != expected.size
      @errors << "Verify: DB has #{db_verses.size} verses, expected #{expected.size}"
      return false
    end

    key_by_id = {}
    db_verses.each do |id, key, content, source_xml, book_id, status, language_id, unit_type_id|
      v = expected[key]
      problem = if v.nil? then 'unexpected verse'
                elsif content != v.content then 'content mismatch'
                elsif source_xml != v.source_xml then 'source XML mismatch'
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

    db_tokens = Hash.new { |h, k| h[k] = [] }
    TextContentToken.unscoped.where(text_content_id: key_by_id.keys)
                    .order(:text_content_id, :position)
                    .pluck(:text_content_id, *TOKEN_FIELDS)
                    .each { |tc_id, *vals| db_tokens[key_by_id[tc_id]] << TOKEN_FIELDS.zip(vals).to_h }

    expected.each do |key, v|
      next if db_tokens[key] == v.tokens.map { |t| t.slice(*TOKEN_FIELDS) }

      @errors << "Verify: #{key}: tokens differ from file"
      return false
    end

    canonical = CanonicalSourceText.where(source_code: source.code, book_code: books.keys)
                                   .pluck(:book_code, :chapter_number, :verse_number, :canonical_text)
    expected_canonical = verses.map { |v| [v.book_code, v.chapter, v.verse.to_s, v.content] }
    if canonical.sort != expected_canonical.sort
      @errors << 'Verify: canonical_source_texts do not match the imported verses'
      return false
    end

    true
  end
end
