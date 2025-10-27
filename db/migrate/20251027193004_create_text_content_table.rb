class CreateTextContentTable < ActiveRecord::Migration[7.0]
  def change
    enable_extension 'pgcrypto' unless extension_enabled?('pgcrypto')
    
    create_table :text_contents, id: :uuid, default: 'gen_random_uuid()' do |t|
      # Foreign keys
      t.references :source, null: false, foreign_key: true, type: :bigint
      t.references :book, null: false, foreign_key: true, type: :bigint
      t.references :text_unit_type, null: false, foreign_key: true, type: :bigint
      t.references :language, null: false, foreign_key: true, type: :bigint

      # Hierarchy / addressing
      t.uuid :parent_unit_id, null: true
      t.integer :chapter_number, null: true
      t.integer :verse_number, null: true
      t.integer :unit_number, null: true

      # The actual text
      t.text :content, null: false

      # Stable natural key for fast lookups
      t.string :unit_key, null: false, limit: 255

      # Canon checkboxes
      t.boolean :canon_catholic, null: false, default: false
      t.boolean :canon_protestant, null: false, default: false
      t.boolean :canon_lutheran, null: false, default: false
      t.boolean :canon_anglican, null: false, default: false
      t.boolean :canon_greek_orthodox, null: false, default: false
      t.boolean :canon_russian_orthodox, null: false, default: false
      t.boolean :canon_georgian_orthodox, null: false, default: false
      t.boolean :canon_western_orthodox, null: false, default: false
      t.boolean :canon_coptic, null: false, default: false
      t.boolean :canon_armenian, null: false, default: false
      t.boolean :canon_ethiopian, null: false, default: false
      t.boolean :canon_syriac, null: false, default: false
      t.boolean :canon_church_east, null: false, default: false
      t.boolean :canon_judaic, null: false, default: false
      t.boolean :canon_samaritan, null: false, default: false
      t.boolean :canon_lds, null: false, default: false
      t.boolean :canon_quran, null: false, default: false

      t.timestamps
    end
    
    add_index :text_contents, :unit_key, unique: true
    add_index :text_contents, :parent_unit_id
    add_index :text_contents, [:source_id, :book_id]
    add_index :text_contents, [:chapter_number, :verse_number]
  end
end
