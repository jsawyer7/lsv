require 'test_helper'

class DictionaryEntryTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  setup do
    DictionaryEntry.delete_all
    %w[dict Dictionary dog t true tea f 0 100% 1000 · a_b axb].each_with_index do |word, i|
      DictionaryEntry.create!(
        line_number: i + 1, word: word, lang: 'English', lang_code: 'en', pos: 'noun',
        raw_json: '{}', raw_sha256: Digest::SHA256.hexdigest(word), payload: { 'word' => word }
      )
    end
  end

  def start_with(prefix)
    DictionaryEntry.ransack(word_start: prefix).result.order(:word).pluck(:word)
  end

  test 'word_start is a case-insensitive prefix match' do
    assert_equal %w[dict Dictionary], start_with('dict')
    assert_equal %w[dict Dictionary], start_with('DICT')
  end

  test 'word_start keeps boolean-looking prefixes as text' do
    assert_equal %w[t tea true], start_with('t')
    assert_equal %w[f], start_with('f')
    assert_equal %w[0], start_with('0')
  end

  test 'word_start treats LIKE wildcards literally' do
    assert_equal %w[100%], start_with('100%')
    assert_equal %w[a_b], start_with('a_')
  end

  test 'word_start matches non-ASCII symbols' do
    assert_equal %w[·], start_with('·')
  end
end
