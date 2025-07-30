class AddMultipleVersesSupportToEvidences < ActiveRecord::Migration[7.0]
  def change
    # Ensure the content column can handle larger JSON data for multiple verses
    change_column :evidences, :content, :text, limit: 16777215 # 16MB limit for JSON content
  end
end
