class CreateComments < ActiveRecord::Migration[7.0]
  def change
    create_table :comments do |t|
      t.references :user, null: false, foreign_key: true
      t.references :commentable, polymorphic: true, null: false
      t.text :content, null: false

      t.timestamps
    end

    # Add composite index for polymorphic association lookups
    add_index :comments, [:commentable_type, :commentable_id]
  end
end
