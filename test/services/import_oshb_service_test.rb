require 'test_helper'
require 'tmpdir'

class ImportOshbServiceTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  # bet + dagesh (ccc 21) + sheva (ccc 10): valid WLC mark order that NFC would reorder.
  NON_NFC = "בְּ".freeze

  def osis(book, verses_xml)
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <osis xmlns="http://www.bibletechnologies.net/2003/OSIS/namespace">
        <osisText osisIDWork="OSHB">
          <div type="book" osisID="#{book}">
            <chapter osisID="#{book}.1">
      #{verses_xml}
            </chapter>
          </div>
        </osisText>
      </osis>
    XML
  end

  GEN = <<~XML.freeze
    <verse osisID="Gen.1.1">
      <w lemma="b/7225" n="1.0" morph="HR/Ncfsa" id="01xeN">#{NON_NFC}/רֵאשִׁית</w>
      <w lemma="1254 a" morph="HVqp3ms" id="01Nvk">בָּרָא</w>
      <seg type="x-paseq">׀</seg>
      <w lemma="5921 a" morph="HR" id="01aaa">עַל</w><seg type="x-maqqef">־</seg><w lemma="d/776" morph="HTd/Ncbsa" id="01bbb">הָ/אָרֶץ</w><seg type="x-sof-pasuq">׃</seg>
      <seg type="x-pe">פ</seg>
    </verse>
    <verse osisID="Gen.1.2">
      <w lemma="1" morph="HNcmsc" id="01ccc">אֲבִי</w><w lemma="5703" morph="HNcmsa" id="01ddd">עַד</w>
      <note type="exegesis">A single word in the text has been divided for exegesis.</note>
      <w type="x-ketiv" lemma="3318" morph="HVhv2ms" id="01eee">הוצא</w><note type="variant"><catchWord>הוצא</catchWord><rdg type="x-qere"><w lemma="3318" morph="HVhv2ms" id="01fff">הַיְצֵא</w></rdg></note>
      <w lemma="8085" morph="HVqv2ms" id="01ggg">שְׁמַ<seg type="x-large">ע</seg></w><seg type="x-sof-pasuq">׃</seg>
      <note>KJV:Gen.1.3</note>
    </verse>
  XML

  JUDG = <<~XML.freeze
    <verse osisID="Judg.1.1">
      <w lemma="1961" morph="HVqw3ms" id="07aaa">וַ/יְהִי</w><seg type="x-sof-pasuq">׃</seg>
      <seg type="x-reversednun">׆</seg>
      <seg type="x-samekh">ס</seg>
    </verse>
  XML

  FILES = %w[Gen.xml Judg.xml].freeze

  setup do
    @dir = Dir.mktmpdir
    write('Gen.xml', osis('Gen', GEN))
    write('Judg.xml', osis('Judg', JUDG))
    write('VerseMap.xml', '<verseMap/>')

    Language.unscoped.find_or_create_by!(code: 'heb') { |l| l.name = 'Hebrew' }
    TextUnitType.unscoped.find_or_create_by!(code: 'BIB_VERSE') { |t| t.name = 'Verse' }
    Book.unscoped.find_or_create_by!(code: 'GEN') { |b| b.std_name = 'Genesis' }
    Book.unscoped.find_or_create_by!(code: 'JUG') { |b| b.std_name = 'Judges' }
  end

  teardown { FileUtils.remove_entry(@dir) }

  def write(name, body) = File.write(File.join(@dir, name), body)

  def import(**opts) = ImportOshbService.new(dir: @dir, dry_run: false, filenames: FILES, **opts).call

  def source = Source.unscoped.find_by!(code: 'MT_WLC')

  def verse(key) = TextContent.unscoped.find_by!(unit_key: "MT_WLC|#{key}")

  test 'rebuilds verse text from words and markers, using the ketiv and skipping notes' do
    result = import
    assert_empty result[:errors]
    assert result[:verified]
    assert_equal 3, result[:created_verses]
    assert_equal 10, result[:created_tokens] # 4 + 5 (incl. ketiv and qere) + 1

    assert_equal "#{NON_NFC}רֵאשִׁית בָּרָא ׀ עַל־הָאָרֶץ׃ פ", verse('GEN|1|1').content
    assert_equal 'אֲבִיעַד הוצא שְׁמַע׃', verse('GEN|1|2').content
    assert_equal 'וַיְהִי׃ ׆ ס', verse('JUG|1|1').content
  end

  test 'never Unicode-normalizes the Hebrew text' do
    import
    content = verse('GEN|1|1').reload.content
    assert content.start_with?(NON_NFC)
    refute_equal content.unicode_normalize(:nfc), content
    assert_equal "#{NON_NFC}/רֵאשִׁית", verse('GEN|1|1').tokens.first.surface
  end

  test 'stores every word with its kind, morphology and exact source XML' do
    import
    tokens = verse('GEN|1|2').tokens.to_a
    assert_equal %w[word word ketiv qere word], tokens.map(&:kind)

    ketiv, qere = tokens[2], tokens[3]
    assert_equal %w[הוצא 3318 HVhv2ms 01eee], [ketiv.surface, ketiv.lemma, ketiv.parsing, ketiv.source_word_id]
    assert_equal 'הַיְצֵא', qere.word

    first = verse('GEN|1|1').tokens.first
    assert_equal ["#{NON_NFC}רֵאשִׁית", 'b/7225', 'HR/Ncfsa', '1.0', 'Gen.1.1'],
                 [first.word, first.lemma, first.parsing, first.source_n, first.ref]
    assert_equal %(<w lemma="8085" morph="HVqv2ms" id="01ggg">שְׁמַ<seg type="x-large">ע</seg></w>), tokens.last.source_xml
    assert verse('GEN|1|2').source_xml.start_with?('<verse osisID="Gen.1.2">')
    assert_includes verse('GEN|1|2').source_xml, '<note>KJV:Gen.1.3</note>'
  end

  test 'imports into MT_WLC as Hebrew verses, with canonical text and the AI lock' do
    import
    tc = verse('GEN|1|1')
    assert_equal %w[heb BIB_VERSE source_import], [tc.language.code, tc.text_unit_type.code, tc.population_status]
    assert_equal tc.content, CanonicalSourceText.find_canonical('MT_WLC', 'GEN', 1, 1).canonical_text
    assert tc.ai_population_locked?
    assert_equal 'already_populated', TextContentPopulationService.new(tc).populate_content_fields(force: true)[:status]
  end

  test 'dry run writes nothing and skips VerseMap.xml' do
    result = ImportOshbService.new(dir: @dir).call
    assert_match(/Mapped files missing on disk/, result[:errors].join) # only 2 of 39 books in this fixture
    refute_match(/VerseMap/, (result[:errors] + result[:warnings]).join)
    assert_nil Source.unscoped.find_by(code: 'MT_WLC')
    assert_equal 0, TextContentToken.count
  end

  test 'unknown markup fails the import instead of being dropped silently' do
    write('Judg.xml', osis('Judg', JUDG.sub('x-samekh', 'x-mystery')))
    assert_match(/unknown seg type "x-mystery"/, import[:errors].join)
    assert_equal 0, TextContent.unscoped.count
  end

  test 'a verse from another book fails the import' do
    write('Judg.xml', osis('Judg', JUDG.sub('Judg.1.1', 'Gen.1.9')))
    assert_match(/does not belong to Judg/, import[:errors].join)
  end

  test 're-import requires REPLACE and only replaces the selected books' do
    import
    assert_match(/REPLACE=true/, import[:errors].join)

    write('Judg.xml', osis('Judg', JUDG.sub(%(<seg type="x-samekh">ס</seg>), %(<seg type="x-pe">פ</seg>))))
    result = import(replace: true, filenames: ['Judg.xml'])
    assert result[:verified], result[:errors].inspect
    assert_equal 'וַיְהִי׃ ׆ פ', verse('JUG|1|1').content
    assert_equal 3, TextContent.unscoped.where(source: source).count
  end

  test 'an existing MT_WLC source without a unit type is fixed; a wrong language blocks the import' do
    heb = Language.unscoped.find_by!(code: 'heb')
    Source.unscoped.create!(code: 'MT_WLC', name: 'Masoretic Text', language: heb, text_unit_type: nil)
    assert import[:verified]
    assert_equal 'BIB_VERSE', source.reload.text_unit_type.code

    source.update!(language: Language.unscoped.find_or_create_by!(code: 'eng') { |l| l.name = 'English' })
    assert_match(/has language eng, expected heb/, import(replace: true)[:errors].join)
  end
end
