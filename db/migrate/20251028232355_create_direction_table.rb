class CreateDirectionTable < ActiveRecord::Migration[7.0]
  def change
    create_table :directions do |t|
      t.text :code, null: false
      t.text :name, null: false
      t.text :description

      t.timestamps
    end
    add_index :directions, :code, unique: true
  end
end
