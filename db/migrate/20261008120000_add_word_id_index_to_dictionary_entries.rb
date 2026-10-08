class AddWordIdIndexToDictionaryEntries < ActiveRecord::Migration[7.0]
  # Build without locking writes on the 1.5M-row table.
  disable_ddl_transaction!

  # The admin index sorts by word (with id as a tiebreaker, since ~84k words
  # repeat). The existing word indexes use text_pattern_ops / trigram ops, which
  # cannot serve ORDER BY word under the database collation, so every page load
  # sorted the whole table. A default-collation btree on (word, id) lets
  # ORDER BY word, id LIMIT n walk the index instead.
  def change
    add_index :dictionary_entries, [:word, :id],
              name: 'index_dictionary_entries_on_word_and_id',
              algorithm: :concurrently
  end
end
