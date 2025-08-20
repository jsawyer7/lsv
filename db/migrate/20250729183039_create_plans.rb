class CreatePlans < ActiveRecord::Migration[7.0]
  def change
    create_table :plans do |t|
      t.string :chargebee_id
      t.string :name
      t.text :description
      t.decimal :price
      t.string :billing_cycle
      t.string :status
      t.jsonb :metadata

      t.timestamps
    end
  end
end
