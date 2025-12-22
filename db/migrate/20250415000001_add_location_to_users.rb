class AddLocationToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :latitude, :decimal, precision: 10, scale: 6
    add_column :users, :longitude, :decimal, precision: 10, scale: 6
    add_column :users, :city, :string
    add_column :users, :country, :string
    add_index :users, [:latitude, :longitude]
  end
end
