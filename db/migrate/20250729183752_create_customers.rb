class CreateCustomers < ActiveRecord::Migration[7.0]
  def change
    create_table :customers do |t|
      t.string :chargebee_id
      t.references :user, null: false, foreign_key: true
      t.string :email
      t.string :first_name
      t.string :last_name
      t.string :company
      t.string :phone
      t.jsonb :metadata

      t.timestamps
    end
  end
end
