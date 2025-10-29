class UpdateTextContentFields < ActiveRecord::Migration[7.0]
  def change
    # Remove unit_number column
    remove_column :text_contents, :unit_number, :integer
    
    # Rename chapter_number to unit_group
    rename_column :text_contents, :chapter_number, :unit_group
    
    # Rename verse_number to unit
    rename_column :text_contents, :verse_number, :unit
  end
end
