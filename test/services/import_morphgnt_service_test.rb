require 'test_helper'
require 'tmpdir'

class ImportMorphgntServiceTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  MATTHEW = <<~TXT
    010101 N- ----NSF- Βίβλος Βίβλος βίβλος βίβλος
    010101 N- ----GSF- γενέσεως γενέσεως γενέσεως γένεσις
    010101 N- ----GSM- Ἰησοῦ Ἰησοῦ Ἰησοῦ Ἰησοῦς
    010101 N- ----GSM- χριστοῦ χριστοῦ Χριστοῦ Χριστός
    010101 N- ----GSM- υἱοῦ υἱοῦ υἱοῦ υἱός
    010101 N- ----GSM- Δαυὶδ Δαυὶδ Δαυίδ Δαυίδ
    010101 N- ----GSM- υἱοῦ υἱοῦ υἱοῦ υἱός
    010101 N- ----GSM- Ἀβραάμ. Ἀβραάμ Ἀβραάμ Ἀβραάμ
    010613 P- -------- ἀπὸ ἀπὸ ἀπό ἀπό
    010613 RA ----GSN- τοῦ τοῦ τοῦ ὁ
    010613 A- ----GSN- ⸀πονηροῦ. πονηροῦ πονηροῦ πονηρός
  TXT

  JUDE = <<~TXT
    260101 N- ----NSM- ⸂Ἰούδας Ἰούδας Ἰούδας Ἰούδας
    260101 N- ----NSM- ⸀1δοῦλος⸃, δοῦλος δοῦλος δοῦλος
  TXT

  setup do
    @dir = Dir.mktmpdir
    write('61-Mt-morphgnt.txt', MATTHEW)
    write('86-Jud-morphgnt.txt', JUDE)

    Language.unscoped.find_or_create_by!(code: 'grc') { |l| l.name = 'Greek' }
    TextUnitType.unscoped.find_or_create_by!(code: 'BIB_VERSE') { |t| t.name = 'Verse' }
    Book.unscoped.find_or_create_by!(code: 'MAT') { |b| b.std_name = 'Matthew' }
    Book.unscoped.find_or_create_by!(code: 'JUD') { |b| b.std_name = 'Jude' }
  end

  teardown { FileUtils.remove_entry(@dir) }

  def write(name, body) = File.write(File.join(@dir, name), body)

  FILES = %w[61-Mt-morphgnt.txt 86-Jud-morphgnt.txt].freeze

  def import(**opts) = ImportMorphgntService.new(dir: @dir, dry_run: false, filenames: FILES, **opts).call

  def source = Source.unscoped.find_by!(code: 'GRK_SBLGNT')

  def verse(key) = TextContent.unscoped.find_by!(unit_key: "GRK_SBLGNT|#{key}")

  test 'imports verses and tokens verbatim, stripping apparatus signs from content only' do
    result = import
    assert_empty result[:errors]
    assert result[:verified]
    assert_equal 3, result[:created_verses]
    assert_equal 13, result[:created_tokens]

    mt = verse('MAT|6|13')
    assert_equal 'ἀπὸ τοῦ πονηροῦ.', mt.content
    assert_equal [6, '13'], [mt.unit_group, mt.unit]
    assert_equal 'source_import', mt.population_status
    assert_equal [], mt.word_for_word_translation
    assert_nil mt.lsv_literal_reconstruction

    token = mt.tokens.last
    assert_equal ['⸀πονηροῦ.', 'πονηροῦ', 'πονηρός', 'A-', '----GSN-', 3],
                 [token.surface, token.word, token.lemma, token.pos, token.parsing, token.position]

    assert_equal 'Ἰούδας δοῦλος,', verse('JUD|1|1').content
    assert_equal 'Ἰούδας δοῦλος,', CanonicalSourceText.find_canonical('GRK_SBLGNT', 'JUD', 1, 1).canonical_text
    assert_equal 'grc', source.language.code
  end

  test 'dry run writes nothing' do
    result = ImportMorphgntService.new(dir: @dir, filenames: FILES).call
    assert_empty result[:errors]
    assert_equal [3, 13], [result[:verses_parsed], result[:tokens_parsed]]
    assert_nil Source.unscoped.find_by(code: 'GRK_SBLGNT')
    assert_equal 0, TextContentToken.count
  end

  test 'a malformed line fails the import and writes nothing' do
    write('86-Jud-morphgnt.txt', JUDE + "260102 N- ----NSM- missing-columns\n")
    result = import
    assert_match(/expected 7 non-empty fields/, result[:errors].join)
    assert_equal 0, TextContent.unscoped.count
  end

  test 'a line from the wrong book fails the import' do
    write('86-Jud-morphgnt.txt', JUDE + "010101 N- ----NSM- x x x x\n")
    assert_match(/book number 01 does not match/, import[:errors].join)
  end

  test 're-import requires REPLACE and only replaces the selected books' do
    import
    assert_match(/REPLACE=true/, import[:errors].join)

    write('86-Jud-morphgnt.txt', JUDE.sub('δοῦλος⸃,', 'δοῦλος⸃.'))
    result = import(replace: true, filenames: ['86-Jud-morphgnt.txt'])
    assert result[:verified], result[:errors].inspect
    assert_equal 'Ἰούδας δοῦλος.', verse('JUD|1|1').content
    assert_equal 3, TextContent.unscoped.where(source: source).count
    assert_equal 'ἀπὸ τοῦ πονηροῦ.', verse('MAT|6|13').content
  end

  test 'an existing source with no text unit type (as in production) is fixed and imported' do
    grc = Language.unscoped.find_by!(code: 'grc')
    Source.unscoped.create!(code: 'GRK_SBLGNT', name: 'SBLGNT (created by hand)', language: grc, text_unit_type: nil)

    dry = ImportMorphgntService.new(dir: @dir, filenames: FILES).call
    assert_empty dry[:errors]
    assert_match(/no text unit type; it will be set to BIB_VERSE/, dry[:warnings].join)

    result = import
    assert result[:verified], result[:errors].inspect
    assert_equal 'BIB_VERSE', source.reload.text_unit_type.code
    assert_equal ['BIB_VERSE'], TextContent.unscoped.where(source: source).map { |tc| tc.text_unit_type.code }.uniq
  end

  test 'an existing source with the wrong language is reported in the dry run and blocks the import' do
    other = Language.unscoped.find_or_create_by!(code: 'eng') { |l| l.name = 'English' }
    Source.unscoped.create!(code: 'GRK_SBLGNT', name: 'SBLGNT (wrong language)', language: other)

    assert_match(/has language eng, expected grc/, ImportMorphgntService.new(dir: @dir, filenames: FILES).call[:errors].join)
    assert_match(/has language eng, expected grc/, import[:errors].join)
    assert_equal 0, TextContent.unscoped.where(source: source).count
  end

  test 'AI population refuses imported verses and writes nothing' do
    import
    tc = verse('MAT|6|13')
    result = TextContentPopulationService.new(tc).populate_content_fields(force: true)

    assert_equal 'already_populated', result[:status]
    tc.reload
    assert_equal 'source_import', tc.population_status
    assert_nil tc.last_population_attempt_at
    assert_equal 'ἀπὸ τοῦ πονηροῦ.', tc.content
  end
end
