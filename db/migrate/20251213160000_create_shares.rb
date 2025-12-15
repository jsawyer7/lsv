class CreateShares < ActiveRecord::Migration[7.0]
  def change
    create_table :shares do |t|
      t.references :user, null: false, foreign_key: true
      t.references :shareable, polymorphic: true, null: false
      t.references :recipient, null: true, foreign_key: { to_table: :users }
      t.text :message
      t.datetime :read_at

      t.timestamps
    end

    add_index :shares, [:shareable_type, :shareable_id]
    add_index :shares, [:recipient_id, :created_at]
    add_index :shares, [:user_id, :recipient_id, :shareable_type, :shareable_id],
              unique: true,
              name: 'index_shares_on_user_recipient_and_shareable',
              where: 'recipient_id IS NOT NULL'
    add_index :shares, [:user_id, :shareable_type, :shareable_id],
              unique: true,
              name: 'index_shares_on_user_and_shareable_reshared',
              where: 'recipient_id IS NULL'
  end
end
