class AddOauthTokensToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :oauth_token, :text unless column_exists?(:users, :oauth_token)
    add_column :users, :oauth_token_secret, :text unless column_exists?(:users, :oauth_token_secret)
    add_column :users, :oauth_refresh_token, :text unless column_exists?(:users, :oauth_refresh_token)
    add_column :users, :oauth_expires_at, :datetime unless column_exists?(:users, :oauth_expires_at)
  end
end
