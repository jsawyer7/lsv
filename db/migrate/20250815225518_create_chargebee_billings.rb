class CreateChargebeeBillings < ActiveRecord::Migration[7.0]
  def change
    create_table :chargebee_billings do |t|
      t.string :chargebee_id, null: false
      t.references :user, null: false, foreign_key: true
      t.references :chargebee_subscription, null: false, foreign_key: true
      t.string :plan_name
      t.datetime :purchase_date
      t.datetime :ending_date
      t.string :status
      t.decimal :amount, precision: 10, scale: 2
      t.string :currency
      t.text :description
      t.jsonb :metadata

      t.timestamps
    end

    add_index :chargebee_billings, :chargebee_id, unique: true
    add_index :chargebee_billings, :purchase_date
    add_index :chargebee_billings, :status
  end
end
