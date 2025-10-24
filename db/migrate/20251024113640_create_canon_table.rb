class CreateCanonTable < ActiveRecord::Migration[7.0]
  def change
    create_table :canons do |t|
      t.text :code, null: false
      t.text :name, null: false
      t.text :description

      t.timestamps
    end
    add_index :canons, :code, unique: true
  end
end
