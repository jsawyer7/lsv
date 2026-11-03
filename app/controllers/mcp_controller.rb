# Model Context Protocol endpoint for Grok Bot custom connectors (read-only).
#
# The Bot sends JSON-RPC over HTTP POST to /mcp with a GrokBotConnection token
# in "Authorization: Bearer <token>" or "X-LSV-Token: <token>". The connection
# decides which tools are listed (LsvMcp::Server). The transport is stateless,
# so any web process can serve any request.
class McpController < ActionController::API
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

    # Rails may already have read the JSON body for params; the transport reads it again.
    request.body.rewind
    status, headers, body = transport.handle_request(Rack::Request.new(request.env))

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
