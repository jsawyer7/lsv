class CreateFamiliesSeed < ActiveRecord::Migration[7.0]
  def change
    create_table :families_seed do |t|
      t.string :code
      t.string :name
      t.text :notes

      t.timestamps
    end
  end
end
