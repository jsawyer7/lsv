class ChangeNamingPreferenceToEnum < ActiveRecord::Migration[7.0]
  def change
    # Add new naming_preference column for enum
    add_column :users, :naming_preference, :integer, default: nil

    # Remove the old foreign key column and its index
    remove_foreign_key :users, :languages, column: :naming_preference_id if foreign_key_exists?(:users, :languages, column: :naming_preference_id)
    remove_index :users, :naming_preference_id if index_exists?(:users, :naming_preference_id)
    remove_column :users, :naming_preference_id, :bigint
  end
end
