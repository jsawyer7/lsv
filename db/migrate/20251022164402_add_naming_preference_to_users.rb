class AddNamingPreferenceToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :naming_preference, :integer, default: 0
  end
end
