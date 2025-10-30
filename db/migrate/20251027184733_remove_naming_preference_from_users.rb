class RemoveNamingPreferenceFromUsers < ActiveRecord::Migration[7.0]
  def change
    remove_column :users, :naming_preference, :string
  end
end
