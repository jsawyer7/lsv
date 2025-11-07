class CreateTextContentApiLogs < ActiveRecord::Migration[7.0]
  def change
    create_table :text_content_api_logs do |t|
      t.uuid :text_content_id
      t.string :source_name, null: false
      t.string :book_code, null: false
      t.integer :chapter
      t.integer :verse
      t.string :action, null: false # 'create_next', 'ai_validate'
      t.text :request_payload
      t.text :response_payload
      t.string :status, null: false # 'success', 'error', 'validation_failed'
      t.text :error_message
      t.string :ai_model_name
      t.datetime :created_at, null: false
    end

    add_index :text_content_api_logs, :text_content_id
    add_index :text_content_api_logs, [:source_name, :book_code, :chapter, :verse], name: 'idx_tc_api_logs_location'
    add_index :text_content_api_logs, :created_at
  end
end

