class CreateFamiliesForFoundations < ActiveRecord::Migration[7.0]
  def change
    create_table :families_for_foundations do |t|
      t.string :code
      t.string :name
      t.string :domain
      t.text :description
      t.integer :display_order
      t.boolean :is_active

      t.timestamps
    end
  end
end
