class AddTraditionHashesToClaims < ActiveRecord::Migration[7.0]
  def change
    add_column :claims, :tradition_hashes, :text
  end
end
