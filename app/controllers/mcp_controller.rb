# Model Context Protocol endpoint for Grok Bot custom connectors (read-only).
#
# The Bot sends JSON-RPC over HTTP POST to /mcp with a GrokBotConnection token
# in "Authorization: Bearer <token>" or "X-LSV-Token: <token>". The connection
# decides which tools are listed (LsvMcp::Server). The transport is stateless,
# so any web process can serve any request.
class McpController < ActionController::API
  # Tool calls are logged by LsvMcp::Tool. Connecting and listing tools are
  # logged here too, so a client's "tool discovery failed" can be checked
  # against what LSV actually received.
  DISCOVERY_METHODS = %w[initialize tools/list].freeze

  before_action :require_https
  before_action :authenticate_connection

  def handle
    server = LsvMcp::Server.build(connection: @connection, remote_ip: request.remote_ip)
    transport = MCP::Server::Transports::StreamableHTTPTransport.new(
      server,
      stateless: true,
      enable_json_response: true,
      # The Host/Origin check guards MCP servers bound to localhost against DNS
      # rebinding. This endpoint is public by design and requires a token instead.
      dns_rebinding_protection: false
    )
    server.transport = transport

    discovery = discovery_request
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    # Rails may already have read the JSON body for params; the transport reads it again.
    request.body.rewind
    status, headers, body = transport.handle_request(Rack::Request.new(request.env))
    record_discovery(discovery, status, body, started) if discovery

    content_type = nil
    headers.each do |name, value|
      next content_type = value if name.casecmp?('Content-Type')

      response.headers[name] = value
    end
    # Rails would otherwise label the body text/html; MCP clients reject anything
    # but application/json or text/event-stream.
    response.content_type = content_type if content_type
    self.status = status
    self.response_body = body
  end

  private

  def discovery_request
    message = JSON.parse(request.raw_post)
    message if message.is_a?(Hash) && DISCOVERY_METHODS.include?(message['method'])
  rescue JSON::ParserError
    nil
  end

  def record_discovery(message, status, body, started)
    reply = JSON.parse(Array(body).join) rescue {}
    error = reply['error'] && reply['error']['message']
    error ||= "HTTP #{status}" unless status == 200
    params = message['params'].is_a?(Hash) ? message['params'].slice('protocolVersion', 'clientInfo') : {}

    GrokBotToolCall.create!(
      grok_bot_connection: @connection,
      tool_name: message['method'],
      arguments: params,
      status: error ? 'error' : 'ok',
      error_message: error,
      result_count: reply.dig('result', 'tools')&.size,
      duration_ms: ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round,
      remote_ip: request.remote_ip
    )
    @connection.touch_usage!(request.remote_ip)
  rescue StandardError => e
    Rails.logger.error("[LsvMcp] could not record #{message['method']}: #{e.class}: #{e.message}")
  end

  def require_https
    return unless Rails.env.production?
    return if request.ssl?

    render_error(403, 'HTTPS is required.')
  end

  def authenticate_connection
    @connection = GrokBotConnection.authenticate(presented_token)
    return if @connection

    response.headers['WWW-Authenticate'] = 'Bearer realm="lsv"'
    render_error(401, 'Missing, invalid or disabled LSV connection token.')
  end

  def presented_token
    header = request.authorization.to_s
    bearer = header[/\ABearer\s+(\S+)\z/i, 1]
    bearer.presence || request.headers['X-LSV-Token'].to_s.strip.presence
  end

  def render_error(status, message)
    render status: status, json: { jsonrpc: '2.0', id: nil, error: { code: -32_001, message: message } }
  end
end
