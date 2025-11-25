class CreatePartyTypes < ActiveRecord::Migration[7.0]
  def change
    create_table :party_types do |t|
      t.string :code, null: false, limit: 50
      t.string :label, null: false
      t.text :description

      t.timestamps
    end
    
    add_index :party_types, :code, unique: true
  end
end
