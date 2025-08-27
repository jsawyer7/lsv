class CreateCanonWorkPreferences < ActiveRecord::Migration[7.0]
  def change
    create_table :canon_work_preferences, id: false do |t|
      t.references :canon, null: false, foreign_key: true
      t.string :work_code, null: false
      t.string :foundation_code
      t.string :numbering_system_code
      t.text :notes

      t.timestamps
    end
    
    add_index :canon_work_preferences, [:canon_id, :work_code], unique: true
  end
end
