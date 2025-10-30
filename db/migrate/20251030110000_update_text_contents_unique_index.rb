class UpdateTextContentsUniqueIndex < ActiveRecord::Migration[7.0]
  def change
    # Remove global unique index on unit_key if present
    if index_exists?(:text_contents, :unit_key, unique: true)
      remove_index :text_contents, column: :unit_key
    end

    # Add composite unique index to allow same unit_key across different sources/books
    add_index :text_contents, [:source_id, :book_id, :unit_key], unique: true, name: 'index_text_contents_on_source_book_unit_key'
  end
end


