class RemoveDuplicateCommentIndex < ActiveRecord::Migration[7.0]
  def change
    # Remove the duplicate index - keep the shorter named one
    remove_index :comments, name: "index_comments_on_commentable_type_and_commentable_id", if_exists: true
  end
end
