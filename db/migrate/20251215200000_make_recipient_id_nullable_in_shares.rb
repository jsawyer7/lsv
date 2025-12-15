class MakeRecipientIdNullableInShares < ActiveRecord::Migration[7.0]
  def up
    # Remove the NOT NULL constraint from recipient_id
    change_column_null :shares, :recipient_id, true

    # Remove the old unique index if it exists
    remove_index :shares, name: 'index_shares_on_user_recipient_and_shareable', if_exists: true

    # Add new unique indexes with WHERE clauses
    add_index :shares, [:user_id, :recipient_id, :shareable_type, :shareable_id],
              unique: true,
              name: 'index_shares_on_user_recipient_and_shareable',
              where: 'recipient_id IS NOT NULL'

    add_index :shares, [:user_id, :shareable_type, :shareable_id],
              unique: true,
              name: 'index_shares_on_user_and_shareable_reshared',
              where: 'recipient_id IS NULL'
  end

  def down
    # Remove the new indexes
    remove_index :shares, name: 'index_shares_on_user_recipient_and_shareable', if_exists: true
    remove_index :shares, name: 'index_shares_on_user_and_shareable_reshared', if_exists: true

    # Add back the old index
    add_index :shares, [:user_id, :recipient_id, :shareable_type, :shareable_id],
              unique: true,
              name: 'index_shares_on_user_recipient_and_shareable'

    # Set recipient_id back to NOT NULL (this will fail if there are NULL values)
    change_column_null :shares, :recipient_id, false
  end
end

