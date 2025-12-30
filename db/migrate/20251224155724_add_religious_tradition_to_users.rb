class AddReligiousTraditionToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :religious_tradition, :string
    add_column :users, :tradition_canon, :string
    add_column :users, :favorite_teachers, :text
  end
end
