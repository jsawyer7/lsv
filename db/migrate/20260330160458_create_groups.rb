class CreateGroups < ActiveRecord::Migration[7.0]
  def change
    create_table :groups do |t|
      t.string :name, null: false
      t.text :description
      t.references :leader, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :groups, :name
  end
end
