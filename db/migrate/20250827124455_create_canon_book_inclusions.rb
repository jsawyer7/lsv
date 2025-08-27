class CreateCanonBookInclusions < ActiveRecord::Migration[7.0]
  def change
    create_table :canon_book_inclusions, id: false do |t|
      t.references :canon, null: false, foreign_key: true
      t.string :work_code, null: false
      t.string :include_from
      t.string :include_to
      t.text :notes

      t.timestamps
    end
    
    add_index :canon_book_inclusions, [:canon_id, :work_code], unique: true
  end
end
