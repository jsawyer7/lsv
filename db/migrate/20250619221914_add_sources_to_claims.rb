class AddSourcesToClaims < ActiveRecord::Migration[7.0]
  def change
    add_column :claims, :primary_sources, :string, array: true, default: []
    add_column :claims, :secondary_sources, :string, array: true, default: []
  end
end
