require 'digest'
require 'json'

# Streams app/admin/dictionary/Wiktnaary Dictionary.jsonl into dictionary_entries.
#
# Design notes:
# - raw_json stores the exact file line (minus trailing \\n) for letter-fidelity.
# - payload stores parsed JSONB for GIN / path search.
# - line_number is the unique identity (word/pos alone is not unique in this dump).
# - Adaptive batching by approximate byte size avoids OOM on ~2MB outlier lines.
class ImportWiktionaryDictionaryService
  DEFAULT_PATH = Rails.root.join('app/admin/dictionary/Wiktnaary Dictionary.jsonl')
  TARGET_BATCH_BYTES = 4 * 1024 * 1024 # ~4MB per insert_all flush
  MAX_BATCH_ROWS = 250

  class Error < StandardError; end

  def initialize(path: DEFAULT_PATH, dry_run: true, limit: nil, truncate: false)
    @path = Pathname.new(path)
    @dry_run = dry_run
    @limit = limit&.to_i
    @truncate = truncate
    @errors = []
    @warnings = []
  end

  def call
    raise Error, "Dictionary file not found: #{@path}" unless @path.exist?

    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    stats = {
      lines_read: 0,
      rows_built: 0,
      inserted: 0,
      parse_errors: 0,
      skipped_blank: 0,
      max_line_bytes: 0,
      max_line_number: nil
    }

    indexes_dropped = false

    unless @dry_run
      configure_session_for_bulk_load!
      if @truncate
        DictionaryEntry.delete_all
        drop_heavy_indexes!
        indexes_dropped = true
      elsif DictionaryEntry.exists?
        raise Error, 'dictionary_entries is not empty. Re-run with TRUNCATE=true or clear the table first.'
      else
        drop_heavy_indexes!
        indexes_dropped = true
      end
    end

    begin
      batch = []
      batch_bytes = 0

      File.open(@path, 'r', encoding: 'UTF-8') do |io|
        io.each_line do |line|
          stats[:lines_read] += 1
          line_number = stats[:lines_read]

          if @limit && line_number > @limit
            stats[:lines_read] -= 1
            break
          end

          # Preserve exact characters; only strip the single trailing LF used by this file.
          raw = line.end_with?("\n") ? line.byteslice(0, line.bytesize - 1) : line
          # Guard against accidental CRLF dumps
          raw = raw.byteslice(0, raw.bytesize - 1) if raw.end_with?("\r")

          byte_len = raw.bytesize
          if byte_len > stats[:max_line_bytes]
            stats[:max_line_bytes] = byte_len
            stats[:max_line_number] = line_number
          end

          if raw.empty?
            stats[:skipped_blank] += 1
            @warnings << "Blank line at #{line_number}"
            next
          end

          row = build_row(line_number, raw)
          unless row
            stats[:parse_errors] += 1
            next
          end

          stats[:rows_built] += 1
          batch << row
          batch_bytes += byte_len

          if batch.size >= MAX_BATCH_ROWS || batch_bytes >= TARGET_BATCH_BYTES
            stats[:inserted] += flush_batch!(batch)
            batch = []
            batch_bytes = 0
            log_progress(stats, started) if (stats[:rows_built] % 25_000).zero?
          end
        end
      end

      stats[:inserted] += flush_batch!(batch) unless batch.empty?
    ensure
      if indexes_dropped
        Rails.logger.info('[dictionary import] rebuilding indexes...')
        recreate_heavy_indexes!
      end
    end

    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
    {
      dry_run: @dry_run,
      path: @path.to_s,
      stats: stats,
      elapsed_seconds: elapsed.round(2),
      errors: @errors,
      warnings: @warnings,
      success: @errors.empty?
    }
  end

  private

  def configure_session_for_bulk_load!
    conn = ActiveRecord::Base.connection
    conn.execute('SET synchronous_commit = OFF')
    conn.execute('SET statement_timeout = 0')
    conn.execute("SET maintenance_work_mem = '1GB'") rescue nil
  end

  HEAVY_INDEXES = [
    {
      name: 'index_dictionary_entries_on_word_pattern',
      sql: 'CREATE INDEX index_dictionary_entries_on_word_pattern ON dictionary_entries (word text_pattern_ops)'
    },
    {
      name: 'index_dictionary_entries_on_lower_word_pattern',
      sql: 'CREATE INDEX index_dictionary_entries_on_lower_word_pattern ON dictionary_entries (lower(word) text_pattern_ops)'
    },
    {
      name: 'index_dictionary_entries_on_word_trgm',
      sql: 'CREATE INDEX index_dictionary_entries_on_word_trgm ON dictionary_entries USING gin (word gin_trgm_ops)'
    },
    {
      name: 'index_dictionary_entries_on_payload_gin',
      sql: 'CREATE INDEX index_dictionary_entries_on_payload_gin ON dictionary_entries USING gin (payload jsonb_path_ops)'
    },
    {
      name: 'index_dictionary_entries_on_lang_code_and_word',
      sql: 'CREATE INDEX index_dictionary_entries_on_lang_code_and_word ON dictionary_entries (lang_code, word)'
    },
    {
      name: 'index_dictionary_entries_on_lang_code_and_pos',
      sql: 'CREATE INDEX index_dictionary_entries_on_lang_code_and_pos ON dictionary_entries (lang_code, pos)'
    },
    {
      name: 'index_dictionary_entries_on_pos',
      sql: 'CREATE INDEX index_dictionary_entries_on_pos ON dictionary_entries (pos)'
    },
    {
      name: 'index_dictionary_entries_on_raw_sha256',
      sql: 'CREATE INDEX index_dictionary_entries_on_raw_sha256 ON dictionary_entries (raw_sha256)'
    }
  ].freeze

  def drop_heavy_indexes!
    conn = ActiveRecord::Base.connection
    HEAVY_INDEXES.each do |idx|
      conn.execute("DROP INDEX IF EXISTS #{idx[:name]}")
    end
  end

  def recreate_heavy_indexes!
    conn = ActiveRecord::Base.connection
    HEAVY_INDEXES.each do |idx|
      conn.execute(idx[:sql])
    end
  end

  def build_row(line_number, raw)
    begin
      payload = JSON.parse(raw)
    rescue JSON::ParserError => e
      @errors << "Line #{line_number}: JSON parse error: #{e.message}"
      return nil
    end

    unless payload.is_a?(Hash)
      @errors << "Line #{line_number}: top-level JSON is not an object"
      return nil
    end

    word = payload['word']
    lang = payload['lang']
    lang_code = payload['lang_code']
    pos = payload['pos']

    if word.nil? || lang.nil? || lang_code.nil? || pos.nil?
      @errors << "Line #{line_number}: missing required word/lang/lang_code/pos"
      return nil
    end

    unless word.is_a?(String) && lang.is_a?(String) && lang_code.is_a?(String) && pos.is_a?(String)
      @errors << "Line #{line_number}: word/lang/lang_code/pos must be strings"
      return nil
    end

    senses = payload['senses']
    senses_count = senses.is_a?(Array) ? senses.size : 0

    now = Time.current
    {
      line_number: line_number,
      word: word,
      lang: lang,
      lang_code: lang_code,
      pos: pos,
      etymology_number: payload.key?('etymology_number') ? payload['etymology_number'].to_s : nil,
      etymology_text: payload['etymology_text'].is_a?(String) ? payload['etymology_text'] : nil,
      source: payload['source'].is_a?(String) ? payload['source'] : nil,
      original_title: payload['original_title'].is_a?(String) ? payload['original_title'] : nil,
      senses_count: senses_count,
      raw_json: raw,
      payload: payload,
      raw_sha256: Digest::SHA256.hexdigest(raw),
      created_at: now,
      updated_at: now
    }
  end

  def flush_batch!(batch)
    return 0 if batch.empty?
    return batch.size if @dry_run

    # insert_all skips validations/callbacks; required for bulk throughput.
    result = DictionaryEntry.insert_all(batch, record_timestamps: false)
    result.length
  rescue => e
    # Fall back to smaller chunks to isolate a bad row without losing progress context
    if batch.size == 1
      @errors << "Insert failed at line #{batch.first[:line_number]}: #{e.message}"
      raise Error, @errors.last
    end

    mid = batch.size / 2
    flush_batch!(batch[0...mid]) + flush_batch!(batch[mid..])
  end

  def log_progress(stats, started)
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
    rate = elapsed.positive? ? (stats[:rows_built] / elapsed) : 0
    Rails.logger.info(
      "[dictionary import] rows=#{stats[:rows_built]} inserted=#{stats[:inserted]} " \
      "rate=#{rate.round(1)}/s errors=#{@errors.size}"
    )
  end
end
