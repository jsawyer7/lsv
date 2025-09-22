class CreateTextUnits < ActiveRecord::Migration[7.0]
  def change
    create_table :text_units, id: false do |t|
      t.string :unit_id, limit: 26, primary_key: true
      t.string :tradition, limit: 32, null: false
      t.string :work_code, limit: 32, null: false
      t.string :division_code, limit: 64, null: false
      t.integer :chapter, null: false
      t.integer :verse, null: false
      t.string :subref, limit: 16

      t.timestamps
    end
    
    add_index :text_units, [:tradition, :division_code, :chapter, :verse, :subref], 
              unique: true, name: 'idx_text_units_unique'
  end
end
