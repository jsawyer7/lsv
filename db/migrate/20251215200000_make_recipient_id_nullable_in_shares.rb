class MakeRecipientIdNullableInShares < ActiveRecord::Migration[7.0]
  def up
    # Only proceed if the shares table exists
    return unless table_exists?(:shares)

    # Check if recipient_id column exists and make it nullable if it's not already
    if column_exists?(:shares, :recipient_id)
      # Get the column definition to check if it's nullable
      column = connection.columns(:shares).find { |c| c.name == 'recipient_id' }
      if column && column.null == false
        change_column_null :shares, :recipient_id, true
      end
    end

    # Check if indexes already exist
    index_exists_1 = index_exists?(:shares, name: 'index_shares_on_user_recipient_and_shareable')
    index_exists_2 = index_exists?(:shares, name: 'index_shares_on_user_and_shareable_reshared')

    # Remove the old unique index if it exists and doesn't have a WHERE clause
    if index_exists_1
      # Check if this index has a WHERE clause by querying pg_indexes
      begin
        index_def = connection.select_value("
          SELECT indexdef FROM pg_indexes
          WHERE schemaname = 'public'
          AND tablename = 'shares'
          AND indexname = 'index_shares_on_user_recipient_and_shareable'
        ")

        # Only remove if it doesn't have a WHERE clause (old version)
        if index_def && !index_def.to_s.include?('WHERE')
          remove_index :shares, name: 'index_shares_on_user_recipient_and_shareable'
          index_exists_1 = false
        end
      rescue => e
        # If we can't check, assume it needs to be recreated
        Rails.logger.warn("Could not check index definition: #{e.message}")
      end
    end

    # Add new unique indexes with WHERE clauses only if they don't exist
    unless index_exists_1
      add_index :shares, [:user_id, :recipient_id, :shareable_type, :shareable_id],
                unique: true,
                name: 'index_shares_on_user_recipient_and_shareable',
                where: 'recipient_id IS NOT NULL'
    end

    unless index_exists_2
      add_index :shares, [:user_id, :shareable_type, :shareable_id],
                unique: true,
                name: 'index_shares_on_user_and_shareable_reshared',
                where: 'recipient_id IS NULL'
    end
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
