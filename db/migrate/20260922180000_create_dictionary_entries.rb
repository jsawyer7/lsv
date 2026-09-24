class CreateDictionaryEntries < ActiveRecord::Migration[7.0]
  def up
    enable_extension 'pg_trgm' unless extension_enabled?('pg_trgm')

    create_table :dictionary_entries do |t|
      # Stable identity from the source JSONL (1-based). Needed because
      # (word, lang_code, pos, etymology_number) is NOT unique in this dump.
      t.integer :line_number, null: false

      # Hot search / filter columns extracted from every record
      t.text :word, null: false
      t.text :lang, null: false
      t.string :lang_code, limit: 16, null: false
      t.string :pos, limit: 64, null: false
      t.text :etymology_number
      t.text :etymology_text
      t.text :source
      t.text :original_title
      t.integer :senses_count, null: false, default: 0

      # Letter-perfect original JSONL line (no trailing newline).
      # This is the source of truth for fidelity verification.
      t.text :raw_json, null: false

      # Parsed JSON for flexible path/GIN queries. Not used for letter-fidelity.
      t.jsonb :payload, null: false, default: {}

      # Integrity fingerprint of raw_json (hex SHA-256)
      t.string :raw_sha256, limit: 64, null: false

      t.timestamps
    end

    add_index :dictionary_entries, :line_number, unique: true, name: 'index_dictionary_entries_on_line_number'
    add_index :dictionary_entries, :raw_sha256, name: 'index_dictionary_entries_on_raw_sha256'

    # Exact lookup / filter
    add_index :dictionary_entries, [:lang_code, :word], name: 'index_dictionary_entries_on_lang_code_and_word'
    add_index :dictionary_entries, [:lang_code, :pos], name: 'index_dictionary_entries_on_lang_code_and_pos'
    add_index :dictionary_entries, :pos, name: 'index_dictionary_entries_on_pos'

    # Left-anchored prefix search: WHERE word LIKE 'dict%'
    execute <<~SQL.squish
      CREATE INDEX index_dictionary_entries_on_word_pattern
      ON dictionary_entries (word text_pattern_ops)
    SQL

    execute <<~SQL.squish
      CREATE INDEX index_dictionary_entries_on_lower_word_pattern
      ON dictionary_entries (lower(word) text_pattern_ops)
    SQL

    # Continuous / fuzzy / substring search via trigram (ILIKE, %, similarity)
    execute <<~SQL.squish
      CREATE INDEX index_dictionary_entries_on_word_trgm
      ON dictionary_entries USING gin (word gin_trgm_ops)
    SQL

    # Nested Wiktionary fields (senses, translations, forms, ...)
    execute <<~SQL.squish
      CREATE INDEX index_dictionary_entries_on_payload_gin
      ON dictionary_entries USING gin (payload jsonb_path_ops)
    SQL
  end

  def down
    drop_table :dictionary_entries
    # leave pg_trgm enabled; other objects may depend on it later
  end
end
