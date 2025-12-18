class MakeRecipientIdNullableInShares < ActiveRecord::Migration[7.0]
  def up
    # Only proceed if the shares table exists
    return unless table_exists?(:shares)

    # Check if recipient_id column exists and make it nullable if it's not already
    if column_exists?(:shares, :recipient_id)
      begin
        # Use SQL to check if column is nullable - safer than loading all columns
        is_nullable = connection.select_value("
          SELECT is_nullable = 'YES'
          FROM information_schema.columns
          WHERE table_schema = 'public'
          AND table_name = 'shares'
          AND column_name = 'recipient_id'
        ")

        if is_nullable == false
          change_column_null :shares, :recipient_id, true
        end
      rescue => e
        # If we can't check, try the old method as fallback
        begin
          column = connection.columns(:shares).find { |c| c.name == 'recipient_id' }
          if column && column.null == false
            change_column_null :shares, :recipient_id, true
          end
        rescue
          # If both methods fail, skip this step
        end
      end
    end

    # Check if indexes already exist using a safer method
    # (The CreateShares migration should have created them with WHERE clauses)
    index_1_exists = safe_index_exists?('index_shares_on_user_recipient_and_shareable')
    index_2_exists = safe_index_exists?('index_shares_on_user_and_shareable_reshared')

    # Only add indexes if they don't exist
    # If they exist, we assume they were created correctly by the CreateShares migration
    unless index_1_exists
      add_index :shares, [:user_id, :recipient_id, :shareable_type, :shareable_id],
                unique: true,
                name: 'index_shares_on_user_recipient_and_shareable',
                where: 'recipient_id IS NOT NULL'
    end

    unless index_2_exists
      add_index :shares, [:user_id, :shareable_type, :shareable_id],
                unique: true,
                name: 'index_shares_on_user_and_shareable_reshared',
                where: 'recipient_id IS NULL'
    end
  end

  private

  def safe_index_exists?(index_name)
    # Use raw SQL query to check index existence - most reliable method
    result = connection.select_value("
      SELECT EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE schemaname = 'public'
        AND tablename = 'shares'
        AND indexname = #{connection.quote(index_name)}
      )
    ")
    result == true || result == 't'
  rescue => e
    # If SQL query fails, try index_exists? as fallback
    begin
      index_exists?(:shares, name: index_name)
    rescue
      # If both methods fail, assume index doesn't exist to be safe
      false
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
