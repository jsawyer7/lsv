class CreateVeritalkValidators < ActiveRecord::Migration[7.0]
  def change
    create_table :veritalk_validators do |t|
      t.string :name, null: false
      t.text :description
      t.text :system_prompt, null: false
      t.boolean :is_active, default: false, null: false
      t.integer :version, default: 1, null: false
      t.references :created_by, polymorphic: true, null: true

      t.timestamps
    end

    add_index :veritalk_validators, :is_active
    add_index :veritalk_validators, :name
  end
end
