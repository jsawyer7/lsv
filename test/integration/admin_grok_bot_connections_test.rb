require 'test_helper'

class AdminGrokBotConnectionsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  self.fixture_table_names = []

  setup do
    @admin = User.create!(email: 'admin@example.com', password: 'password123', confirmed_at: Time.current)
    @admin.update_columns(role: User.roles[:admin])
  end

  test 'an admin creates a connection and sees its token exactly once' do
    sign_in @admin
    post admin_grok_bot_connections_path, params: {
      grok_bot_connection: { name: 'Challenge Bot', description: 'Reviews challenges', enabled: '1', scopes: ['', 'scripture', 'claims'] }
    }
    assert_response :success
    assert_equal 'no-store', response.headers['Cache-Control']

    connection = GrokBotConnection.last
    token = response.body[/value="(lsv_[^"]+)"/, 1]
    assert token, 'token is shown'
    assert_equal connection, GrokBotConnection.authenticate(token)
    assert_equal %w[scripture claims], connection.scopes
    assert_equal @admin, connection.created_by
    assert_includes response.body, 'http://www.example.com/mcp'

    get admin_grok_bot_connection_path(connection)
    assert_response :success
    assert_includes response.body, connection.token_prefix
    refute_includes response.body, token
  end

  test 'regenerating shows a new token and revokes the old one' do
    sign_in @admin
    connection = GrokBotConnection.create!(name: 'Bot')
    old_token = connection.plain_token

    post regenerate_token_admin_grok_bot_connection_path(connection)
    assert_response :success
    new_token = response.body[/value="(lsv_[^"]+)"/, 1]
    assert_equal connection, GrokBotConnection.authenticate(new_token)
    assert_nil GrokBotConnection.authenticate(old_token)
  end

  test 'toggle disables and re-enables a connection' do
    sign_in @admin
    connection = GrokBotConnection.create!(name: 'Bot')

    post toggle_admin_grok_bot_connection_path(connection)
    refute connection.reload.enabled
    post toggle_admin_grok_bot_connection_path(connection)
    assert connection.reload.enabled
  end

  test 'index, edit and show pages render' do
    sign_in @admin
    connection = GrokBotConnection.create!(name: 'Bot', scopes: %w[dictionary])
    connection.tool_calls.create!(tool_name: 'lookup_name', arguments: { name: 'moses' }, status: 'ok', result_count: 2, duration_ms: 4)

    get admin_grok_bot_connections_path
    assert_response :success
    assert_includes response.body, 'Bot'

    get edit_admin_grok_bot_connection_path(connection)
    assert_response :success

    get admin_grok_bot_connection_path(connection)
    assert_response :success
    assert_includes response.body, 'lookup_name'
  end

  test 'non-admins cannot manage connections' do
    user = User.create!(email: 'user@example.com', password: 'password123', confirmed_at: Time.current)
    sign_in user

    post admin_grok_bot_connections_path, params: { grok_bot_connection: { name: 'Sneaky', scopes: ['claims'] } }
    assert_equal 0, GrokBotConnection.count
    refute_match(/lsv_/, response.body)

    connection = GrokBotConnection.create!(name: 'Bot')
    digest = connection.token_digest
    post regenerate_token_admin_grok_bot_connection_path(connection)
    post toggle_admin_grok_bot_connection_path(connection)
    get admin_grok_bot_connection_path(connection)
    refute_includes response.body, connection.token_prefix
    assert_equal [digest, true], [connection.reload.token_digest, connection.enabled]
  end
end
