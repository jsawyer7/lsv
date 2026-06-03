class AddPresetAvatarIdToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :preset_avatar_id, :integer
  end
end
