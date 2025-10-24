class CreateBookTable < ActiveRecord::Migration[7.0]
  def change
    create_table :books do |t|
      t.text :code, null: false
      t.text :std_name, null: false
      t.text :description

      t.timestamps
    end
    add_index :books, :code, unique: true
  end
end
