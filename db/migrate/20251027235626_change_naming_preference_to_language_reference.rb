class ChangeNamingPreferenceToLanguageReference < ActiveRecord::Migration[7.0]
  def change
    # Add the new foreign key column (the old column was already removed)
    add_reference :users, :naming_preference, null: true, foreign_key: { to_table: :languages }
  end
end
