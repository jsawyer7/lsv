class CreateConversationsAndMessages < ActiveRecord::Migration[7.0]
  def change
    create_table :conversations do |t|
      t.references :user, null: false, foreign_key: true
      t.string :topic, null: false
      t.text :summary

      t.timestamps
    end

    create_table :conversation_messages do |t|
      t.references :conversation, null: false, foreign_key: true
      t.string :role, null: false # 'user' or 'assistant'
      t.text :content, null: false
      t.integer :position, null: false

      t.timestamps
    end

    add_index :conversation_messages, [:conversation_id, :position], unique: true

    create_table :conversation_summaries do |t|
      t.references :conversation, null: false, foreign_key: true
      t.text :content, null: false
      t.integer :position, null: false

      t.timestamps
    end

    add_index :conversation_summaries, [:conversation_id, :position], unique: true
  end
end
