# Imports the Tanzil Qur'an (Uthmani text, Hafs ʿan ʿĀṣim, version 1.1) from
# app/admin/books/Quran/quran-uthmani.xml into
#   - text_contents           one row per ayah (source QURAN_ARABIC_STD, book QUR,
#                             unit_group = surah, unit = ayah)
#   - canonical_source_texts  gold-master ayah text for fidelity checks
#
# Deterministic file import only: nothing here calls or prepares data for AI.
# QURAN_ARABIC_STD is listed in TextContent::AI_LOCKED_SOURCE_CODES and rows get
# population_status 'source_import', so the AI population pipeline skips them.
#
# The file was downloaded from https://tanzil.net/download/ with pause marks,
# sajdah signs and superscript alif on, and rub-el-hizb signs off.
# Tanzil's terms allow verbatim copies only, so each ayah's text attribute is
# stored exactly as it is in the file and never Unicode-normalized (~92% of
# ayahs are deliberately not NFC). The exact <aya .../> element is kept in
# source_xml, including the separate bismillah attribute that opens 112 surahs;
# the bismillah is not added to ayah 1's text (it is ayah 1:1 only in Al-Fatiha).
class ImportTanzilQuranService
  FILE = Rails.root.join('app/admin/books/Quran/quran-uthmani.xml')
  SOURCE_CODE = 'QURAN_ARABIC_STD'.freeze
  BOOK_CODE = 'QUR'.freeze
  HEADER = 'Tanzil Quran Text (Uthmani, Version 1.1)'.freeze

  SOURCE_ATTRIBUTES = {
    description: 'Arabic Qur’an, Uthmānī script, Hafs ʿan ʿĀṣim reading: Tanzil Quran Text (Uthmani, Version 1.1), ' \
                 'imported verbatim. Source: Tanzil Project, https://tanzil.net',
    provenance: 'Tanzil Quran Text (Uthmani, Version 1.1) XML from https://tanzil.net/download/, ' \
                'imported verbatim by ImportTanzilQuranService.',
    rights_json: {
      'text' => 'Tanzil Quran Text — Copyright (C) 2007-2026 Tanzil Project — Creative Commons Attribution 3.0. ' \
                'Verbatim copies only; changing the text is not allowed.',
      'attribution' => 'Tanzil Project (https://tanzil.net)',
      'source_url' => 'https://tanzil.net/download/',
      'updates' => 'https://tanzil.net/updates/'
    }
  }.freeze

  SURAHS = 114
  AYAHS = 6236
  # Surah 1's bismillah is its first ayah; surah 9 (At-Tawba) has none.
  NO_BISMILLAH = [1, 9].freeze
  AYA_RAW_RE = %r{<aya\b[^>]*/>}
  AYA_ATTRIBUTES = %w[index text bismillah].freeze
  BATCH_SIZE = 1000

  class Error < StandardError; end

  Ayah = Struct.new(:surah, :ayah, :content, :source_xml, keyword_init: true)

  def initialize(dry_run: true, replace: false, file: FILE)
    @file = Pathname(file)
    @dry_run = dry_run
    @replace = replace
    @errors = []
    @warnings = []
  end

  def call
    raise Error, "Qur'an file not found: #{@file}" unless @file.exist?

    ayahs = parse_file
    check_parsed!(ayahs)

    book = Book.unscoped.find_by(code: BOOK_CODE) or raise Error, "Book #{BOOK_CODE} missing in DB"
    resolve_reference_data!

    source = Source.unscoped.find_by(code: SOURCE_CODE)
    check_existing_source!(source)
    existing = source ? TextContent.unscoped.where(source_id: source.id, book_id: book.id).count : 0
    if existing.positive? && !@replace
      @errors << "#{SOURCE_CODE} already has #{existing} text_contents row(s). Re-run with REPLACE=true to delete and re-import them."
    end

    result = {
      dry_run: @dry_run,
      source_code: SOURCE_CODE,
      source_exists: source.present?,
      existing_rows: existing,
      file_sha256: Digest::SHA256.file(@file).hexdigest,
      surahs_parsed: ayahs.map(&:surah).uniq.size,
      ayahs_parsed: ayahs.size,
      created_ayahs: 0,
      verified: false
    }

    unless @dry_run || @errors.any?
      without_sql_logging do
        # requires_new: a savepoint, so the Rollback below also works when called inside another transaction.
        ActiveRecord::Base.transaction(requires_new: true) do
          source = ensure_source!
          delete_existing!(source, book) if existing.positive?
          result[:created_ayahs] = insert_ayahs!(source, book, ayahs)
          result[:verified] = verify_import!(source, book, ayahs)
          # Never leave a partial or unverified import behind.
          raise ActiveRecord::Rollback unless result[:verified]
        end
      end
      if result[:verified]
        result[:source_exists] = true
      else
        result[:created_ayahs] = 0
      end
    end

    result.merge(errors: @errors, warnings: @warnings)
  end

  private

  def parse_file
    raw = File.binread(@file).force_encoding(Encoding::UTF_8)
    return fail!('invalid UTF-8') unless raw.valid_encoding?
    return fail!("header does not name #{HEADER.inspect}") unless raw[0, 2000].include?(HEADER)

    doc = Nokogiri::XML(raw) { |config| config.strict.nonet }
    return fail!("root element is <#{doc.root&.name}>, expected <quran>") unless doc.root&.name == 'quran'

    aya_nodes = doc.xpath('/quran/sura/aya')
    raw_ayas = raw.scan(AYA_RAW_RE)
    if raw_ayas.size != aya_nodes.size || doc.xpath('//aya').size != aya_nodes.size
      return fail!("#{raw_ayas.size} raw <aya> slices vs #{aya_nodes.size} parsed ayahs")
    end

    unexpected = doc.root.xpath('*[not(self::sura)] | sura/*[not(self::aya)] | sura/aya/*').map(&:name).uniq
    return fail!("unexpected elements: #{unexpected.join(', ')}") if unexpected.any?

    aya_nodes.zip(raw_ayas).filter_map { |node, raw_aya| build_ayah(node, raw_aya) }
  rescue Nokogiri::XML::SyntaxError => e
    fail!("XML error: #{e.message}")
  end

  def build_ayah(node, raw_aya)
    surah = node.parent['index'].to_s
    ayah = node['index'].to_s
    ref = "#{surah}:#{ayah}"
    extra = node.attributes.keys - AYA_ATTRIBUTES

    problem = if !surah.match?(/\A[1-9]\d*\z/) || !ayah.match?(/\A[1-9]\d*\z/) then 'bad surah/ayah index'
              elsif extra.any? then "unexpected attributes #{extra.join(', ')}"
              elsif node['text'].blank? then 'empty text'
              # The parser decodes entities and folds whitespace in attributes; the
              # stored text must be the file's characters, so both must agree.
              elsif !raw_aya.include?(%( index="#{ayah}" text="#{node['text']}"))
                'raw slice does not match the parsed text'
              end
    if problem
      @errors << "#{ref}: #{problem}"
      return nil
    end

    Ayah.new(surah: surah.to_i, ayah: ayah.to_i, content: node['text'], source_xml: raw_aya)
  end

  def fail!(message)
    @errors << "#{@file.basename}: #{message}"
    []
  end

  def check_parsed!(ayahs)
    return if ayahs.empty?

    surah_numbers = ayahs.map(&:surah).uniq
    @errors << "surahs are not 1..#{SURAHS} in order" unless surah_numbers == (1..SURAHS).to_a
    @errors << "#{ayahs.size} ayahs, expected #{AYAHS}" unless ayahs.size == AYAHS

    ayahs.group_by(&:surah).each do |surah, surah_ayahs|
      numbers = surah_ayahs.map(&:ayah)
      @errors << "surah #{surah}: ayah numbering is not 1..#{numbers.max}" unless numbers == (1..numbers.max).to_a

      has_bismillah = surah_ayahs.first.source_xml.include?(' bismillah="')
      if has_bismillah == NO_BISMILLAH.include?(surah)
        @errors << "surah #{surah}: bismillah attribute #{has_bismillah ? 'unexpected' : 'missing'}"
      end
    end

    ayahs.each do |a|
      next unless a.content.match?(/\s{2}|\A\s|\s\z|[\t\n\r]/)

      @errors << "#{a.surah}:#{a.ayah}: stray whitespace in text"
    end
  end

  # Rows always use these explicitly resolved ids, never whatever an existing
  # source row happens to hold (ids differ between environments).
  def resolve_reference_data!
    @language = Language.unscoped.find_by(code: 'ara') or raise Error, 'Language ara (Arabic) missing'
    @unit_type = TextUnitType.unscoped.find_by(code: 'QUR_AYAH') or raise Error, 'TextUnitType QUR_AYAH missing'
  end

  # QURAN_ARABIC_STD exists in the admin data with unit type QUR_SURA; rows are
  # ayahs, so the import switches it to QUR_AYAH. A wrong language blocks the import.
  def check_existing_source!(source)
    return unless source

    if source.language_id != @language.id
      actual = Language.unscoped.find_by(id: source.language_id)&.code || 'none'
      @errors << "Existing source #{source.code} (id #{source.id}) has language #{actual}, expected ara. Fix it in admin before importing."
    end

    return if source.text_unit_type_id == @unit_type.id

    actual = TextUnitType.unscoped.find_by(id: source.text_unit_type_id)&.code || 'none'
    @warnings << "Existing source #{source.code} (id #{source.id}) has text unit type #{actual}; it will be set to QUR_AYAH."
  end

  def ensure_source!
    source = Source.unscoped.find_or_initialize_by(code: SOURCE_CODE)
    source.name = 'Qur’an (Uthmānī text, Hafs ʿan ʿĀṣim)' if source.new_record?
    source.assign_attributes(SOURCE_ATTRIBUTES)
    source.language = @language
    source.text_unit_type = @unit_type
    source.save!
    source
  end

  def delete_existing!(source, book)
    scope = TextContent.unscoped.where(source_id: source.id, book_id: book.id)
    ids = scope.select(:id)
    TextContentToken.unscoped.where(text_content_id: ids).delete_all
    CanonTextContent.where(text_content_id: ids).delete_all
    TextTranslation.unscoped.where(text_content_id: ids).delete_all
    scope.delete_all
    CanonicalSourceText.where(source_code: source.code, book_code: BOOK_CODE).delete_all
  end

  def unit_key(source, a) = "#{source.code}|#{BOOK_CODE}|#{a.surah}|#{a.ayah}"

  def insert_ayahs!(source, book, ayahs)
    now = Time.current
    created = 0

    ayahs.each_slice(BATCH_SIZE) do |batch|
      rows = batch.map do |a|
        {
          source_id: source.id,
          book_id: book.id,
          text_unit_type_id: @unit_type.id,
          language_id: @language.id,
          unit_group: a.surah,
          unit: a.ayah.to_s,
          unit_key: unit_key(source, a),
          content: a.content,
          source_xml: a.source_xml,
          word_for_word_translation: [],
          population_status: TextContent::SOURCE_IMPORT_STATUS,
          created_at: now,
          updated_at: now
        }
      end

      # insert_all skips TextContent's normalize callback, so content is stored exactly as in the file.
      created += TextContent.insert_all!(rows).length

      CanonicalSourceText.insert_all!(batch.map do |a|
        {
          source_code: source.code, book_code: BOOK_CODE, chapter_number: a.surah,
          verse_number: a.ayah.to_s, canonical_text: a.content, created_at: now, updated_at: now
        }
      end)
    end

    created
  end

  # Production logs SQL at DEBUG; the batched inserts would print megabytes of SQL.
  def without_sql_logging
    logger = ActiveRecord::Base.logger
    return yield unless logger

    previous = logger.level
    logger.level = [previous, Logger::INFO].max
    yield
  ensure
    logger.level = previous if logger && previous
  end

  # Re-reads everything from the DB and compares it against the parsed file:
  # every ayah's text and XML must match exactly.
  def verify_import!(source, book, ayahs)
    expected = ayahs.to_h { |a| [unit_key(source, a), a] }

    db_rows = TextContent.unscoped.where(source_id: source.id, book_id: book.id)
                         .pluck(:unit_key, :unit_group, :unit, :content, :source_xml, :population_status, :language_id, :text_unit_type_id)
    if db_rows.size != expected.size
      @errors << "Verify: DB has #{db_rows.size} ayahs, expected #{expected.size}"
      return false
    end

    db_rows.each do |key, surah, ayah, content, source_xml, status, language_id, unit_type_id|
      a = expected[key]
      problem = if a.nil? then 'unexpected ayah'
                elsif [surah, ayah] != [a.surah, a.ayah.to_s] then 'wrong surah/ayah'
                elsif content != a.content then 'content mismatch'
                elsif source_xml != a.source_xml then 'source XML mismatch'
                elsif status != TextContent::SOURCE_IMPORT_STATUS then "status #{status}"
                elsif language_id != @language.id then 'wrong language'
                elsif unit_type_id != @unit_type.id then 'wrong text unit type'
                end
      if problem
        @errors << "Verify: #{key}: #{problem}"
        return false
      end
    end

    canonical = CanonicalSourceText.where(source_code: source.code, book_code: BOOK_CODE)
                                   .pluck(:chapter_number, :verse_number, :canonical_text)
    if canonical.sort != ayahs.map { |a| [a.surah, a.ayah.to_s, a.content] }.sort
      @errors << 'Verify: canonical_source_texts do not match the imported ayahs'
      return false
    end

    true
  end
end
