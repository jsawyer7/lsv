class CreateNumberingLabels < ActiveRecord::Migration[7.0]
  def change
    create_table :numbering_labels do |t|
      t.integer :numbering_system_id, null: false
      t.string :system_code, null: false
      t.string :label, null: false
      t.string :locale
      t.string :applies_to
      t.text :description

      t.timestamps
    end
    
    add_foreign_key :numbering_labels, :numbering_systems, column: :numbering_system_id
    add_index :numbering_labels, [:numbering_system_id, :system_code], unique: true
  end
end
