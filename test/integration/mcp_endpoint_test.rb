require 'test_helper'

class McpEndpointTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  setup do
    @connection = GrokBotConnection.create!(name: 'Bot', scopes: GrokBotConnection::SCOPES.keys)
    @token = @connection.plain_token

    greek = Language.unscoped.create!(code: 'grc', name: 'Greek')
    verse_type = TextUnitType.unscoped.create!(code: 'BIB_VERSE', name: 'Verse')
    @source = Source.unscoped.create!(code: 'LXX_TEST', name: 'Test LXX', language: greek, text_unit_type: verse_type)
    @book = Book.unscoped.create!(code: 'JOS', std_name: 'Joshua')
    { '41' => 'πρῶτος', '42' => 'δεύτερος', '42a' => 'τρίτος', '43' => 'τέταρτος' }.each do |verse, text|
      TextContent.insert_all!([{ source_id: @source.id, book_id: @book.id, text_unit_type_id: verse_type.id,
                                 language_id: greek.id, unit_group: 21, unit: verse, content: text,
                                 unit_key: "LXX_TEST|JOS|21|#{verse}", created_at: Time.current, updated_at: Time.current }])
    end
    verse = TextContent.unscoped.find_by!(unit_key: 'LXX_TEST|JOS|21|42')
    verse.tokens.create!(position: 1, ref: '062142', surface: 'δεύτερος', word: 'δεύτερος', lemma: 'δεύτερος', parsing: '----NSM-')

    @user = User.create!(email: 'claimant@example.com', password: 'password123', confirmed_at: Time.current)
    @claim = Claim.create!(user: @user, content: 'Joshua divided the land')
    @evidence = @claim.evidences.create!(content: 'Joshua 21', sources: [1])
    @challenge = Challenge.create!(user: @user, claim: @claim, evidence: @evidence, text: 'Not in chapter 21')
  end

  def rpc(method, params = nil, token: @token, header: 'Authorization')
    value = header == 'Authorization' ? "Bearer #{token}" : token
    post '/mcp', params: { jsonrpc: '2.0', id: 1, method: method, params: params }.compact.to_json,
                 headers: { 'Content-Type' => 'application/json', 'Accept' => 'application/json, text/event-stream',
                            'MCP-Protocol-Version' => '2025-06-18', header => value }
    JSON.parse(response.body)
  end

  def call_tool(name, arguments = {})
    result = rpc('tools/call', { name: name, arguments: arguments })['result']
    [result['isError'], result['content'].first['text']]
  end

  def tool_data(name, arguments = {})
    error, text = call_tool(name, arguments)
    refute error, text
    JSON.parse(text)
  end

  test 'rejects requests without a valid, enabled token' do
    rpc('tools/list', token: nil)
    assert_response :unauthorized
    assert_equal 'Bearer realm="lsv"', response.headers['WWW-Authenticate']

    rpc('tools/list', token: 'lsv_not-a-real-token')
    assert_response :unauthorized

    @connection.update!(enabled: false)
    rpc('tools/list')
    assert_response :unauthorized
  end

  test 'accepts the token as a Bearer header or an X-LSV-Token header' do
    assert rpc('initialize', { protocolVersion: '2025-06-18', capabilities: {}, clientInfo: { name: 't', version: '1' } })['result']
    assert_response :success
    assert_equal 'application/json', response.media_type
    assert_equal 'lsv', rpc('initialize', { protocolVersion: '2025-06-18', capabilities: {}, clientInfo: { name: 't', version: '1' } },
                            header: 'X-LSV-Token').dig('result', 'serverInfo', 'name')
  end

  test 'lists only the tools of the allowed data groups, all marked read-only' do
    tools = rpc('tools/list')['result']['tools']
    assert_equal LsvMcp::Server::TOOLS.map(&:tool_name).sort, tools.map { |t| t['name'] }.sort
    tools.each do |t|
      assert_equal({ 'readOnlyHint' => true, 'destructiveHint' => false, 'idempotentHint' => true, 'openWorldHint' => false },
                   t['annotations'].slice('readOnlyHint', 'destructiveHint', 'idempotentHint', 'openWorldHint'), t['name'])
    end

    @connection.update!(scopes: %w[dictionary])
    assert_equal %w[lookup_dictionary lookup_name], rpc('tools/list')['result']['tools'].map { |t| t['name'] }.sort
  end

  test 'a tool outside the connection scopes cannot be called' do
    @connection.update!(scopes: %w[dictionary])
    error = rpc('tools/call', { name: 'get_claim', arguments: { claim_id: @claim.id } })
    assert(error['error'] || error.dig('result', 'isError'))
    refute_includes response.body, 'Joshua divided the land'
  end

  test 'get_verses returns exact text, includes lettered verses in their number and orders them' do
    data = tool_data('get_verses', { source: 'lxx_test', book: 'Joshua', chapter: 21, verse_from: 42 })
    assert_equal %w[42 42a], data['verses'].map { |v| v['verse'] }
    assert_equal %w[δεύτερος τρίτος], data['verses'].map { |v| v['text'] }
    assert_equal 'JOS 21:42a', data['verses'].last['reference']

    whole = tool_data('get_verses', { source: 'LXX_TEST', book: 'JOS', chapter: 21, include_words: true })
    assert_equal %w[41 42 42a 43], whole['verses'].map { |v| v['verse'] }
    assert_equal ['δεύτερος'], whole['verses'][1]['words'].map { |w| w['lemma'] }
  end

  test 'include_words allows up to 60 verses' do
    verse_type = TextUnitType.unscoped.find_by!(code: 'BIB_VERSE')
    rows = (1..61).map do |n|
      { source_id: @source.id, book_id: @book.id, text_unit_type_id: verse_type.id, language_id: @source.language_id,
        unit_group: 22, unit: n.to_s, content: "v#{n}", unit_key: "LXX_TEST|JOS|22|#{n}",
        created_at: Time.current, updated_at: Time.current }
    end
    TextContent.insert_all!(rows)

    assert_equal 60, tool_data('get_verses', { source: 'LXX_TEST', book: 'JOS', chapter: 22, verse_to: 60, verse_from: 1,
                                               include_words: true })['count']
    error, text = call_tool('get_verses', { source: 'LXX_TEST', book: 'JOS', chapter: 22, include_words: true })
    assert error
    assert_match(/limited to 60 verses/, text)
  end

  test 'lookup_dictionary returns every sense of an entry' do
    senses = (1..21).map { |n| { 'glosses' => ["sense #{n}"] } }
    DictionaryEntry.create!(line_number: 1, word: 'in', lang: 'English', lang_code: 'en', pos: 'prep',
                            raw_json: '{}', raw_sha256: '0' * 64, payload: { 'senses' => senses })

    entry = tool_data('lookup_dictionary', { word: 'in', pos: 'prep', limit: 20 })['entries'].sole
    assert_equal 21, entry['senses_total']
    assert_equal (1..21).map { |n| ["sense #{n}"] }, entry['senses'].map { |s| s['glosses'] }
  end

  test 'connecting and listing tools are logged' do
    rpc('initialize', { protocolVersion: '2025-06-18', capabilities: {}, clientInfo: { name: 'grok', version: '1' } })
    rpc('tools/list')

    list, init = @connection.tool_calls.recent.first(2)
    assert_equal ['tools/list', 'ok', LsvMcp::Server::TOOLS.size], [list.tool_name, list.status, list.result_count]
    assert_equal ['initialize', 'ok', { 'protocolVersion' => '2025-06-18', 'clientInfo' => { 'name' => 'grok', 'version' => '1' } }],
                 [init.tool_name, init.status, init.arguments]
    assert @connection.reload.last_used_at

    rpc('tools/list', token: 'lsv_not-a-real-token')
    assert_equal 2, GrokBotToolCall.count
  end

  test 'tool errors are reported to the Bot and logged' do
    error, text = call_tool('get_verses', { source: 'NOPE', book: 'JOS', chapter: 1 })
    assert error
    assert_match(/Unknown source "NOPE"/, text)

    error, text = call_tool('get_verses', { source: 'LXX_TEST', book: 'JOS', chapter: 21, extra: 1 })
    assert error
    assert_match(/additional property/, text)

    log = @connection.tool_calls.recent.first
    assert_equal ['get_verses', 'error', { 'source' => 'NOPE', 'book' => 'JOS', 'chapter' => 1 }],
                 [log.tool_name, log.status, log.arguments]
  end

  test 'successful calls are logged and mark the connection as used' do
    data = tool_data('search_verses', { text: 'ΤΡΊΤΟ' }) # case-insensitive; no final sigma, whose capital lowercases to σ

    assert_equal ['LXX_TEST|JOS|21|42a'], data['verses'].map { |v| v['unit_key'] }

    log = @connection.tool_calls.recent.first
    assert_equal ['search_verses', 'ok', 1], [log.tool_name, log.status, log.result_count]
    assert @connection.reload.last_used_at
  end

  test 'claims tools return the claim, evidence and challenge without user details' do
    data = tool_data('get_claim', { claim_id: @claim.id })
    assert_equal 'Joshua divided the land', data['claim']['content']
    assert_equal ['tanakh'], data['evidences'].first['sources']
    assert_equal [@challenge.id], data['challenges'].map { |c| c['id'] }

    challenge = tool_data('get_challenge', { challenge_id: @challenge.id })
    assert_equal 'Not in chapter 21', challenge['challenge']['text']
    assert_equal @claim.id, challenge['claim']['id']
    refute_includes response.body, 'claimant@example.com'

    assert_equal [@claim.id], tool_data('search_claims', { text: 'divided' })['claims'].map { |c| c['id'] }
  end

  test 'tools run in a read-only transaction' do
    writer = Class.new(LsvMcp::Tool) do
      requires_scope 'scripture'
      tool_name 'test_writer'
      def run
        Book.unscoped.create!(code: 'XXX', std_name: 'Should not exist')
      end
    end

    response = writer.call(server_context: { connection: @connection, remote_ip: '127.0.0.1' })
    assert response.error?
    assert_nil Book.unscoped.find_by(code: 'XXX')
    assert_equal 'error', @connection.tool_calls.recent.first.status
  end
end
