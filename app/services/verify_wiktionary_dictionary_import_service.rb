require 'digest'
require 'json'

# Letter-exact verification of dictionary_entries against the source JSONL.
# Compares every file line to raw_json / raw_sha256 / line_number.
class VerifyWiktionaryDictionaryImportService
  DEFAULT_PATH = Rails.root.join('app/admin/dictionary/Wiktnaary Dictionary.jsonl')

  class Error < StandardError; end

  def initialize(path: DEFAULT_PATH, limit: nil)
    @path = Pathname.new(path)
    @limit = limit&.to_i
    @mismatches = []
  end

  def call
    raise Error, "Dictionary file not found: #{@path}" unless @path.exist?

    db_count = DictionaryEntry.count
    stats = {
      file_line_count: 0,
      matched: 0,
      content_mismatch: 0,
      sha_mismatch: 0,
      missing_in_db: 0,
      field_mismatch: 0
    }

    pending_keys = []
    pending_raw = {}

    File.open(@path, 'r', encoding: 'UTF-8') do |io|
      io.each_line do |line|
        stats[:file_line_count] += 1
        break if @limit && stats[:file_line_count] > @limit

        raw = line.end_with?("\n") ? line.byteslice(0, line.bytesize - 1) : line
        raw = raw.byteslice(0, raw.bytesize - 1) if raw.end_with?("\r")

        pending_keys << stats[:file_line_count]
        pending_raw[stats[:file_line_count]] = raw

        if pending_keys.size >= 500
          flush_pending!(pending_keys, pending_raw, stats)
          pending_keys = []
          pending_raw = {}
        end
      end
    end

    flush_pending!(pending_keys, pending_raw, stats) if pending_keys.any?

    if @limit
      stats[:file_line_count] = [stats[:file_line_count], @limit].min
      extra_in_db = DictionaryEntry.where('line_number > ?', @limit).count
      count_mismatch = false
    else
      extra_in_db = [db_count - stats[:file_line_count], 0].max
      count_mismatch = db_count != stats[:file_line_count]
    end

    {
      path: @path.to_s,
      file_line_count: stats[:file_line_count],
      db_count: db_count,
      matched: stats[:matched],
      content_mismatch: stats[:content_mismatch],
      sha_mismatch: stats[:sha_mismatch],
      missing_in_db: stats[:missing_in_db],
      field_mismatch: stats[:field_mismatch],
      extra_in_db: extra_in_db,
      count_mismatch: count_mismatch,
      sample_mismatches: @mismatches.first(20),
      perfect: stats[:content_mismatch].zero? &&
               stats[:sha_mismatch].zero? &&
               stats[:missing_in_db].zero? &&
               stats[:field_mismatch].zero? &&
               extra_in_db.zero? &&
               !count_mismatch &&
               stats[:matched] == stats[:file_line_count]
    }
  end

  private

  def flush_pending!(pending_keys, pending_raw, stats)
    rows = DictionaryEntry.where(line_number: pending_keys).index_by(&:line_number)

    pending_keys.each do |ln|
      raw = pending_raw[ln]
      row = rows[ln]
      unless row
        stats[:missing_in_db] += 1
        record_mismatch(ln, 'missing_in_db')
        next
      end

      if row.raw_json != raw
        stats[:content_mismatch] += 1
        record_mismatch(ln, 'raw_json_mismatch', raw, row.raw_json)
        next
      end

      expected_sha = Digest::SHA256.hexdigest(raw)
      if row.raw_sha256 != expected_sha
        stats[:sha_mismatch] += 1
        record_mismatch(ln, 'sha_mismatch')
        next
      end

      begin
        payload = JSON.parse(raw)
      rescue JSON::ParserError
        stats[:field_mismatch] += 1
        record_mismatch(ln, 'db_row_ok_but_raw_unparseable')
        next
      end

      if row.word != payload['word'] ||
         row.lang != payload['lang'] ||
         row.lang_code != payload['lang_code'] ||
         row.pos != payload['pos']
        stats[:field_mismatch] += 1
        record_mismatch(ln, 'extracted_field_mismatch')
        next
      end

      stats[:matched] += 1
    end
  end

  def record_mismatch(line_number, kind, expected = nil, actual = nil)
    return if @mismatches.size >= 50

    entry = { line_number: line_number, kind: kind }
    if expected && actual
      entry[:expected_len] = expected.length
      entry[:actual_len] = actual.length
      idx = (0...[expected.length, actual.length].max).find { |i| expected[i] != actual[i] }
      entry[:first_diff_at] = idx
      if idx
        from = [idx - 10, 0].max
        entry[:expected_slice] = expected[from, 40]
        entry[:actual_slice] = actual[from, 40]
      end
    end
    @mismatches << entry
  end
end
