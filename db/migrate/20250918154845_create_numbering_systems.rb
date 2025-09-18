class CreateNumberingSystems < ActiveRecord::Migration[7.0]
  def change
    create_table :numbering_systems do |t|
      t.string :code, null: false
      t.string :name, null: false
      t.text :description

      t.timestamps
    end
    
    add_index :numbering_systems, :code, unique: true
  end
end
