class CreateTextPayloads < ActiveRecord::Migration[7.0]
  def change
    create_table :text_payloads, id: false do |t|
      t.string :payload_id, limit: 26, primary_key: true
      t.string :unit_id, limit: 26, null: false
      t.string :language, limit: 8, null: false
      t.string :script, limit: 8, null: false
      t.string :edition_id, limit: 128, null: false
      t.string :layer, limit: 32, null: false
      t.text :content, null: false
      t.jsonb :meta
      t.string :checksum_sha256, limit: 64, null: false
      t.string :source_id, limit: 26, null: false
      t.string :license, limit: 256, null: false
      t.string :version, limit: 64

      t.timestamps
    end
    
    add_foreign_key :text_payloads, :text_units, column: :unit_id, primary_key: :unit_id
    add_foreign_key :text_payloads, :source_registries, column: :source_id, primary_key: :source_id
    add_index :text_payloads, [:unit_id, :edition_id, :layer, :language], 
              unique: true, name: 'idx_text_payloads_unique'
  end
end
