class AddPartyAndGenreToTextContents < ActiveRecord::Migration[7.0]
  def change
    add_column :text_contents, :addressed_party_code, :string, limit: 50
    add_column :text_contents, :addressed_party_custom_name, :text
    add_column :text_contents, :responsible_party_code, :string, limit: 50
    add_column :text_contents, :responsible_party_custom_name, :text
    add_column :text_contents, :genre_code, :string, limit: 50
    
    add_foreign_key :text_contents, :party_types, column: :addressed_party_code, primary_key: :code
    add_foreign_key :text_contents, :party_types, column: :responsible_party_code, primary_key: :code
    add_foreign_key :text_contents, :genre_types, column: :genre_code, primary_key: :code
  end
end
