class CreateSourceTable < ActiveRecord::Migration[7.0]
  def change
    create_table :sources do |t|
      t.text :code, null: false
      t.text :name, null: false
      t.text :description
      t.references :language, null: false, foreign_key: true
      t.jsonb :rights_json
      t.text :provenance

      t.timestamps
    end
    add_index :sources, :code, unique: true
  end
end
