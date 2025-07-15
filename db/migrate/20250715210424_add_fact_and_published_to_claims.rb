class AddFactAndPublishedToClaims < ActiveRecord::Migration[7.0]
  def change
    add_column :claims, :fact, :boolean, default: false
    add_column :claims, :published, :boolean, default: false
  end
end
