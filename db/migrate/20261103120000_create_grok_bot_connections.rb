class CreateGrokBotConnections < ActiveRecord::Migration[7.0]
  # A Grok Bot connection is an access token an admin issues so a Grok Bot
  # (via a custom MCP connector) can read LSV data through /mcp.
  #   - token_digest is the SHA-256 of the token; the token itself is shown once
  #     and never stored. token_prefix identifies it in the admin panel.
  #   - scopes lists the data groups the connection may read
  #     (GrokBotConnection::SCOPES).
  # grok_bot_tool_calls is the audit log of every tool call made with a connection.
  def change
    create_table :grok_bot_connections do |t|
      t.string :name, null: false
      t.text :description
      t.boolean :enabled, null: false, default: true
      t.string :token_digest, null: false, limit: 64
      t.string :token_prefix, null: false, limit: 16
      t.string :scopes, array: true, null: false, default: []
      t.references :created_by, foreign_key: { to_table: :users, on_delete: :nullify }
      t.datetime :token_generated_at, null: false
      t.datetime :last_used_at
      t.string :last_used_ip
      t.timestamps
    end
    add_index :grok_bot_connections, :token_digest, unique: true

    create_table :grok_bot_tool_calls do |t|
      t.references :grok_bot_connection, null: false, index: false, foreign_key: { on_delete: :cascade }
      t.string :tool_name, null: false
      t.jsonb :arguments, null: false, default: {}
      t.string :status, null: false
      t.text :error_message
      t.integer :result_count
      t.integer :duration_ms, null: false
      t.string :remote_ip
      t.datetime :created_at, null: false
    end
    add_index :grok_bot_tool_calls, [:grok_bot_connection_id, :created_at], name: 'index_grok_bot_tool_calls_on_connection_and_created_at'
  end
end
