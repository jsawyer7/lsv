class AddTermsConsentToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :terms_agreed_at, :datetime
    add_column :users, :location_consent, :boolean, default: false
    add_index :users, :terms_agreed_at
  end
end
