class CreateCanons < ActiveRecord::Migration[7.0]
  def change
    create_table :canons do |t|
      t.string :code
      t.string :name
      t.string :domain_code
      t.text :description
      t.boolean :is_official
      t.integer :display_order

      t.timestamps
    end
  end
end
