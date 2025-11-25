class CreateGenreTypes < ActiveRecord::Migration[7.0]
  def change
    create_table :genre_types do |t|
      t.string :code, null: false, limit: 50
      t.string :label, null: false
      t.text :description

      t.timestamps
    end
    
    add_index :genre_types, :code, unique: true
  end
end
