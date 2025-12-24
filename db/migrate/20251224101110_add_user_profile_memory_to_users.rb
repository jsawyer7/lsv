class AddUserProfileMemoryToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :veritalk_profile_memory, :text
  end
end
