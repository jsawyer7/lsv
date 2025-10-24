class CreateLanguageTable < ActiveRecord::Migration[7.0]
  def change
    create_table :languages do |t|
      t.text :code, null: false
      t.text :name, null: false
      t.text :description

      t.timestamps
    end
    add_index :languages, :code, unique: true
  end
end
