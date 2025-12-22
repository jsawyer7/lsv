class AddOauthTokensToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :oauth_token, :text
    add_column :users, :oauth_token_secret, :text
    add_column :users, :oauth_refresh_token, :text
    add_column :users, :oauth_expires_at, :datetime
  end
end
