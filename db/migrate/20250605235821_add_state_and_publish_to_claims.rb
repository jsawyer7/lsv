class AddStateAndPublishToClaims < ActiveRecord::Migration[7.0]
  def change
    add_column :claims, :state, :string, default: 'draft', null: false
    add_column :claims, :publish, :boolean, default: false, null: false
  end
end
