class CreateVeritalkTokenUsages < ActiveRecord::Migration[7.0]
  def change
    create_table :veritalk_token_usages do |t|
      t.references :user, null: false, foreign_key: true
      t.references :conversation, null: false, foreign_key: true
      t.integer :input_tokens
      t.integer :output_tokens
      t.integer :total_tokens
      t.datetime :used_at

      t.timestamps
    end
  end
end
