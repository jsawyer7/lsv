require 'test_helper'
require 'tmpdir'

class ImportTanzilQuranServiceTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  # Taken from the file rather than typed: editors may Unicode-normalize Arabic,
  # and the import must keep the file's exact characters.
  FILE_XML = File.read(ImportTanzilQuranService::FILE)
  def self.aya(surah, ayah) = FILE_XML[/<sura index="#{surah}" .*?<\/sura>/m][/<aya index="#{ayah}" [^>]*\/>/]
  def self.text(xml) = xml[/ text="([^"]*)"/, 1]

  BISMILLAH = text(aya(1, 1))
  AL_BAQARA_1 = aya(2, 1)

  setup do
    @ara = Language.unscoped.find_or_create_by!(code: 'ara') { |l| l.name = 'Arabic' }
    TextUnitType.unscoped.find_or_create_by!(code: 'QUR_SURA') { |t| t.name = 'Surah' }
    TextUnitType.unscoped.find_or_create_by!(code: 'QUR_AYAH') { |t| t.name = 'Ayah' }
    Book.unscoped.find_or_create_by!(code: 'QUR') { |b| b.std_name = "Qur'an" }
    @dir = Dir.mktmpdir
  end

  teardown { FileUtils.remove_entry(@dir) }

  def import(**opts) = ImportTanzilQuranService.new(dry_run: false, **opts).call

  def ayah(ref) = TextContent.unscoped.find_by!(unit_key: "QURAN_ARABIC_STD|QUR|#{ref}")

  # The real file with one edit, written to a temp dir.
  def edited_file
    path = File.join(@dir, 'quran-uthmani.xml')
    File.write(path, yield(FILE_XML.dup))
    path
  end

  test 'imports all 6236 ayahs verbatim and verifies them' do
    result = import
    assert_empty result[:errors]
    assert result[:verified]
    assert_equal [114, 6236, 6236], result.values_at(:surahs_parsed, :ayahs_parsed, :created_ayahs)

    assert_equal BISMILLAH, ayah('1|1').content
    assert_equal self.class.text(AL_BAQARA_1), ayah('2|1').content
    assert_equal 286, TextContent.unscoped.where(unit_group: 2).count
    assert_equal self.class.text(self.class.aya(114, 6)), ayah('114|6').content
  end

  test 'never Unicode-normalizes the text and keeps the bismillah only in the source XML' do
    import
    content = ayah('1|1').reload.content
    refute_equal content.unicode_normalize(:nfc), content

    al_baqara = ayah('2|1')
    assert_equal AL_BAQARA_1, al_baqara.source_xml
    assert_includes AL_BAQARA_1, %( bismillah="#{BISMILLAH}")
    refute_includes al_baqara.content, BISMILLAH
    refute_includes ayah('9|1').source_xml, 'bismillah'
  end

  test 'imports as Arabic ayahs with canonical text, Tanzil attribution and the AI lock' do
    Source.unscoped.create!(code: 'QURAN_ARABIC_STD', name: 'Qur’an**', language: @ara,
                            text_unit_type: TextUnitType.unscoped.find_by!(code: 'QUR_SURA'))
    result = import
    assert_match(/has text unit type QUR_SURA; it will be set to QUR_AYAH/, result[:warnings].join)

    source = Source.unscoped.find_by!(code: 'QURAN_ARABIC_STD')
    assert_equal ['Qur’an**', 'QUR_AYAH'], [source.name, source.text_unit_type.code]
    assert_includes source.rights_json['text'], 'Creative Commons Attribution 3.0'
    assert_includes source.provenance, 'https://tanzil.net'

    tc = ayah('2|255')
    assert_equal %w[ara QUR_AYAH source_import], [tc.language.code, tc.text_unit_type.code, tc.population_status]
    assert_equal [2, '255'], [tc.unit_group, tc.unit]
    assert_equal tc.content, CanonicalSourceText.find_canonical('QURAN_ARABIC_STD', 'QUR', 2, 255).canonical_text
    assert tc.ai_population_locked?
  end

  test 'dry run writes nothing' do
    result = ImportTanzilQuranService.new.call
    assert_empty result[:errors]
    assert_equal 6236, result[:ayahs_parsed]
    assert_equal 0, TextContent.unscoped.count
    assert_nil Source.unscoped.find_by(code: 'QURAN_ARABIC_STD')
  end

  test 're-import requires REPLACE' do
    import
    assert_match(/REPLACE=true/, import[:errors].join)
    assert import(replace: true)[:verified]
    assert_equal 6236, TextContent.unscoped.count
  end

  test 'a missing ayah, a missing bismillah or an unknown attribute fails the import' do
    {
      'surah 1: ayah numbering is not 1..' => ->(xml) { xml.sub(self.class.aya(1, 3), '') },
      'surah 2: bismillah attribute missing' => ->(xml) { xml.sub(AL_BAQARA_1, AL_BAQARA_1.sub(%( bismillah="#{BISMILLAH}"), '')) },
      'unexpected attributes juz' => ->(xml) { xml.sub('<aya index="3" ', '<aya juz="1" index="3" ') }
    }.each do |message, edit|
      result = import(file: edited_file(&edit))
      assert_match(/#{Regexp.escape(message)}/, result[:errors].join, message)
    end
    assert_equal 0, TextContent.unscoped.count
  end

  test 'a file whose header is not Tanzil Uthmani 1.1 is rejected' do
    result = import(file: edited_file { |xml| xml.sub('Uthmani, Version 1.1', 'Simple, Version 1.1') })
    assert_match(/header does not name/, result[:errors].join)
  end
end
