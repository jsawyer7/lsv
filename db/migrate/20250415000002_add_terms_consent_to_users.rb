class AddTermsConsentToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :terms_agreed_at, :datetime unless column_exists?(:users, :terms_agreed_at)
    add_column :users, :location_consent, :boolean, default: false unless column_exists?(:users, :location_consent)
    add_index :users, :terms_agreed_at unless index_exists?(:users, :terms_agreed_at)
  end
end
