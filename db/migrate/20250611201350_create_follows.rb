class CreateFollows < ActiveRecord::Migration[7.0]
  def change
    create_table :follows do |t|
      t.references :user, null: false, foreign_key: true
      t.bigint :followed_user, null: false

      t.timestamps
    end

    add_foreign_key :follows, :users, column: :followed_user
    add_index :follows, [:user_id, :followed_user], unique: true
  end
end
