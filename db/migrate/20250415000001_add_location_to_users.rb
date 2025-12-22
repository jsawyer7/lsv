class AddLocationToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :latitude, :decimal, precision: 10, scale: 6 unless column_exists?(:users, :latitude)
    add_column :users, :longitude, :decimal, precision: 10, scale: 6 unless column_exists?(:users, :longitude)
    add_column :users, :city, :string unless column_exists?(:users, :city)
    add_column :users, :country, :string unless column_exists?(:users, :country)
    add_index :users, [:latitude, :longitude] unless index_exists?(:users, [:latitude, :longitude])
  end
end
