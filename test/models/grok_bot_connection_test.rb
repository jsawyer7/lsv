require 'test_helper'

class GrokBotConnectionTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test 'issues a token on create and stores only its digest' do
    connection = GrokBotConnection.create!(name: 'Bot', scopes: %w[scripture])
    token = connection.plain_token

    assert_match(/\Alsv_[1-9A-HJ-NP-Za-km-z]{40}\z/, token)
    assert_equal OpenSSL::Digest::SHA256.hexdigest(token), connection.token_digest
    assert_equal token.first(12), connection.token_prefix
    refute_includes GrokBotConnection.connection.select_rows('SELECT * FROM grok_bot_connections').flatten.map(&:to_s), token
    assert_nil GrokBotConnection.find(connection.id).plain_token
  end

  test 'authenticates only an enabled connection with the exact token' do
    connection = GrokBotConnection.create!(name: 'Bot')
    token = connection.plain_token

    assert_equal connection, GrokBotConnection.authenticate(token)
    assert_nil GrokBotConnection.authenticate("#{token}x")
    assert_nil GrokBotConnection.authenticate(token.delete_prefix('lsv_'))
    assert_nil GrokBotConnection.authenticate('')
    assert_nil GrokBotConnection.authenticate(nil)

    connection.update!(enabled: false)
    assert_nil GrokBotConnection.authenticate(token)
  end

  test 'regenerating the token revokes the old one' do
    connection = GrokBotConnection.create!(name: 'Bot')
    old_token = connection.plain_token
    new_token = connection.regenerate_token!

    refute_equal old_token, new_token
    assert_nil GrokBotConnection.authenticate(old_token)
    assert_equal connection, GrokBotConnection.authenticate(new_token)
  end

  test 'accepts only known scopes and drops blanks from the form' do
    connection = GrokBotConnection.create!(name: 'Bot', scopes: ['', 'claims', 'claims', 'dictionary'])
    assert_equal %w[claims dictionary], connection.scopes
    assert connection.scope?(:claims)
    refute connection.scope?('scripture')

    invalid = GrokBotConnection.new(name: 'Bot', scopes: %w[users])
    refute invalid.valid?
    assert_match(/unknown values: users/, invalid.errors[:scopes].join)
  end

  test 'deleting a connection deletes its call log' do
    connection = GrokBotConnection.create!(name: 'Bot')
    connection.tool_calls.create!(tool_name: 'list_sources', status: 'ok', duration_ms: 1)
    connection.destroy!
    assert_equal 0, GrokBotToolCall.count
  end
end
