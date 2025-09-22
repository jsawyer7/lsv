class CreateCanonMaps < ActiveRecord::Migration[7.0]
  def change
    create_table :canon_maps, id: false do |t|
      t.string :canon_id, limit: 64, null: false
      t.string :unit_id, limit: 26, null: false
      t.integer :sequence_index, null: false

      t.timestamps
    end
    
    add_foreign_key :canon_maps, :text_units, column: :unit_id, primary_key: :unit_id
    add_index :canon_maps, [:canon_id, :unit_id], unique: true, name: 'idx_canon_maps_primary'
  end
end
