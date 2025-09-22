class CreateSourceRegistries < ActiveRecord::Migration[7.0]
  def change
    create_table :source_registries, id: false do |t|
      t.string :source_id, limit: 26, primary_key: true
      t.string :name, limit: 256, null: false
      t.string :publisher, limit: 256
      t.string :contact, limit: 256
      t.string :license, limit: 256
      t.text :url
      t.string :version, limit: 64
      t.string :checksum_sha256, limit: 64
      t.text :notes

      t.timestamps
    end
  end
end
