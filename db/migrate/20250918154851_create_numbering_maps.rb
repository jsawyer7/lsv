class CreateNumberingMaps < ActiveRecord::Migration[7.0]
  def change
    create_table :numbering_maps do |t|
      t.integer :numbering_system_id, null: false
      t.string :unit_id, null: false
      t.string :work_code, null: false
      t.string :l1
      t.string :l2
      t.string :l3
      t.integer :n_book
      t.integer :n_chapter
      t.integer :n_verse
      t.string :n_sub
      t.string :status

      t.timestamps
    end
    
    add_foreign_key :numbering_maps, :numbering_systems, column: :numbering_system_id
    add_index :numbering_maps, [:numbering_system_id, :unit_id], unique: true
    add_index :numbering_maps, :work_code
  end
end
