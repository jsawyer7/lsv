class AddNormalizedContentToClaims < ActiveRecord::Migration[7.0]
  def change
    add_column :claims, :normalized_content, :text
    add_index :claims, :normalized_content
  end
end
