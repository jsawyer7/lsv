require 'test_helper'
require 'digest'
require 'json'
require 'tempfile'

class WiktionaryDictionaryImportTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  setup do
    DictionaryEntry.delete_all if ActiveRecord::Base.connection.table_exists?(:dictionary_entries)
  end

  test 'import copies every character from JSONL into raw_json and searchable columns' do
    skip 'dictionary_entries table missing — run migrations' unless ActiveRecord::Base.connection.table_exists?(:dictionary_entries)

    fixture = build_fixture_file([
      { 'word' => 'alpha', 'lang' => 'English', 'lang_code' => 'en', 'pos' => 'noun',
        'senses' => [{ 'glosses' => ['first letter'], 'id' => 'en-noun-alpha' }],
        'etymology_text' => "From Greek ἄλφα" },
      { 'word' => 'free', 'lang' => 'English', 'lang_code' => 'en', 'pos' => 'adj',
        'etymology_number' => '1',
        'senses' => [{ 'glosses' => ['not imprisoned'] }, { 'glosses' => ['without cost'] }],
        'synonyms' => [{ 'word' => 'unbound' }] },
      # Intentional duplicate identity (word/lang/pos/etymology_number) — must both import
      { 'word' => 'free', 'lang' => 'English', 'lang_code' => 'en', 'pos' => 'adj',
        'etymology_number' => '1',
        'senses' => [{ 'glosses' => ['alternate entry'] }] }
    ])

    result = ImportWiktionaryDictionaryService.new(path: fixture.path, dry_run: false, truncate: true).call
    assert result[:success], result[:errors].inspect
    assert_equal 3, result[:stats][:inserted]
    assert_equal 3, DictionaryEntry.count

    verification = VerifyWiktionaryDictionaryImportService.new(path: fixture.path).call
    assert verification[:perfect], verification.inspect

    # Letter-exact including non-ASCII
    row1 = DictionaryEntry.find_by!(line_number: 1)
    expected_raw = File.readlines(fixture.path, chomp: true).first
    assert_equal expected_raw, row1.raw_json
    assert_includes row1.raw_json, 'ἄλφα'
    assert_equal 'alpha', row1.word
    assert_equal 'noun', row1.pos
    assert_equal 1, row1.senses_count
    assert_equal Digest::SHA256.hexdigest(expected_raw), row1.raw_sha256

    # Duplicate identities kept as separate line_numbers
    assert_equal 2, DictionaryEntry.where(word: 'free', pos: 'adj').count
  ensure
    fixture&.close!
  end

  test 'verify fails if a single character is altered in DB' do
    skip 'dictionary_entries table missing — run migrations' unless ActiveRecord::Base.connection.table_exists?(:dictionary_entries)

    fixture = build_fixture_file([
      { 'word' => 'beta', 'lang' => 'English', 'lang_code' => 'en', 'pos' => 'noun',
        'senses' => [{ 'glosses' => ['second'] }] }
    ])

    ImportWiktionaryDictionaryService.new(path: fixture.path, dry_run: false, truncate: true).call
    row = DictionaryEntry.find_by!(line_number: 1)
    row.update_columns(raw_json: row.raw_json.sub('beta', 'beza'))

    verification = VerifyWiktionaryDictionaryImportService.new(path: fixture.path).call
    assert_equal false, verification[:perfect]
    assert verification[:content_mismatch].positive?
  ensure
    fixture&.close!
  end

  test 'dry run does not write rows' do
    skip 'dictionary_entries table missing — run migrations' unless ActiveRecord::Base.connection.table_exists?(:dictionary_entries)

    fixture = build_fixture_file([
      { 'word' => 'gamma', 'lang' => 'English', 'lang_code' => 'en', 'pos' => 'noun',
        'senses' => [{ 'glosses' => ['third'] }] }
    ])

    result = ImportWiktionaryDictionaryService.new(path: fixture.path, dry_run: true).call
    assert result[:success]
    assert_equal 1, result[:stats][:rows_built]
    assert_equal 0, DictionaryEntry.count
  ensure
    fixture&.close!
  end

  private

  def build_fixture_file(objects)
    file = Tempfile.new(['wiktionary_fixture', '.jsonl'])
    objects.each do |obj|
      file.write(JSON.generate(obj))
      file.write("\n")
    end
    file.flush
    file
  end
end
