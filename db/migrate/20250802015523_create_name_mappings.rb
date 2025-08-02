class CreateNameMappings < ActiveRecord::Migration[7.0]
  def change
    create_table :name_mappings do |t|
      t.string :internal_id, null: false, index: { unique: true }
      t.string :jewish
      t.string :christian
      t.string :muslim
      t.string :actual
      t.string :ethiopian

      t.timestamps
    end

    add_index :name_mappings, :jewish
    add_index :name_mappings, :christian
    add_index :name_mappings, :muslim
    add_index :name_mappings, :actual
    add_index :name_mappings, :ethiopian
  end
end
