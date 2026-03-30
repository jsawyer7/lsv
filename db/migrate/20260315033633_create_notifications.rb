class CreateNotifications < ActiveRecord::Migration[7.0]
  def change
    create_table :notifications do |t|
      t.references :user, null: false, foreign_key: true
      t.references :actor, foreign_key: { to_table: :users }
      t.string :key, null: false
      t.string :notifiable_type
      t.bigint :notifiable_id
      t.text :message
      t.datetime :read_at

      t.timestamps
    end

    add_index :notifications, [:notifiable_type, :notifiable_id]
    add_index :notifications, [:user_id, :read_at]
  end
end
