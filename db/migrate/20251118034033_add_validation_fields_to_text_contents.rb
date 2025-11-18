class AddValidationFieldsToTextContents < ActiveRecord::Migration[7.0]
  def change
    add_column :text_contents, :content_populated_at, :datetime
    add_column :text_contents, :content_populated_by, :text
    add_column :text_contents, :content_validated_at, :datetime
    add_column :text_contents, :content_validated_by, :text
    add_column :text_contents, :content_validation_result, :jsonb
    add_column :text_contents, :validation_notes, :text
  end
end
