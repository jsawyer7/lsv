class AddItemPriceIdToChargebeePlans < ActiveRecord::Migration[7.0]
  def change
    add_column :chargebee_plans, :chargebee_item_price_id, :string
  end
end
