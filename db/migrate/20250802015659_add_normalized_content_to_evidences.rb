class AddNormalizedContentToEvidences < ActiveRecord::Migration[7.0]
  def change
    add_column :evidences, :normalized_content, :text
    add_index :evidences, :normalized_content
  end
end
