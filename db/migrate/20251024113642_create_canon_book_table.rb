class CreateCanonBookTable < ActiveRecord::Migration[7.0]
  def change
    create_table :canon_books do |t|
      t.references :canon, null: false, foreign_key: true
      t.references :book, null: false, foreign_key: true
      t.integer :seq_no, null: false
      t.boolean :included_bool, null: false, default: true
      t.text :description

      t.timestamps
    end
  end
end
