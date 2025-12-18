class CreateCanonicalSourceText < ActiveRecord::Migration[7.0]
  def change
    create_table :canonical_source_texts, id: false do |t|
      t.string :source_code, limit: 50, null: false
      t.string :book_code, limit: 10, null: false
      t.integer :chapter_number, null: false
      t.string :verse_number, limit: 10, null: false  # String to support sub-verses like "17a"
      t.text :canonical_text, null: false
      t.timestamps

      # Composite primary key
      t.index [:source_code, :book_code, :chapter_number, :verse_number], 
              unique: true, 
              name: 'index_canonical_source_texts_unique'
    end
  end
end
