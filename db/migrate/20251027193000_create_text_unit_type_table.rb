class CreateTextUnitTypeTable < ActiveRecord::Migration[7.0]
  def change
    create_table :text_unit_types do |t|
      t.text :code, null: false
      t.text :name, null: false
      t.text :description

      t.timestamps
    end
    add_index :text_unit_types, :code, unique: true
  end
end
