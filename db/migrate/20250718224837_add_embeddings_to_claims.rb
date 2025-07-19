class AddEmbeddingsToClaims < ActiveRecord::Migration[7.0]
        def change
    add_column :claims, :content_embedding, :vector, limit: 3072
    add_column :claims, :normalized_content_hash, :string

    # Add indexes for faster duplicate detection
    add_index :claims, :normalized_content_hash
    add_index :claims, [:normalized_content_hash, :user_id]
  end
end
