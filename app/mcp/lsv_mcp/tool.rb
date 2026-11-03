module LsvMcp
  # Base class for the read-only tools Grok Bot can call through /mcp.
  #
  # Each subclass declares the data group it belongs to (requires_scope) and
  # implements #run, returning a Hash that is sent to the Bot as JSON.
  # Every call:
  #   - runs inside a Postgres READ ONLY transaction with a statement timeout,
  #     so the endpoint cannot write to the database even by mistake;
  #   - is re-checked against the connection's scopes;
  #   - is recorded in grok_bot_tool_calls.
  # Raise LsvMcp::Tool::Error for messages the Bot should see (bad reference,
  # nothing found); any other exception is logged and reported as an internal error.
  class Tool < MCP::Tool
    class Error < StandardError; end

    STATEMENT_TIMEOUT = '5s'.freeze
    READ_ONLY_ANNOTATIONS = { read_only_hint: true, destructive_hint: false, idempotent_hint: true, open_world_hint: false }.freeze
    MAX_TEXT = 4_000

    class << self
      attr_reader :scope

      def requires_scope(name)
        @scope = name.to_s
      end

      # MCP::Tool resets annotations on every subclass; without these hints a
      # client treats the tool as destructive and may ask a human to approve it.
      def inherited(subclass)
        super
        subclass.annotations(**READ_ONLY_ANNOTATIONS)
      end

      def call(server_context:, **args)
        connection = server_context[:connection]
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        data = nil
        error = nil

        begin
          raise Error, "This connection is not allowed to read #{scope} data." unless connection.scope?(scope)

          data = read_only { new.run(**args) }
        rescue Error => e
          error = e.message
        rescue ActiveRecord::QueryCanceled
          error = 'The query took too long. Narrow it down (e.g. add a source or book, or lower the limit).'
        rescue StandardError => e
          Rails.logger.error("[LsvMcp] #{tool_name} failed: #{e.class}: #{e.message}\n#{e.backtrace&.first(10)&.join("\n")}")
          error = 'Internal error in LSV while running this tool.'
        end

        record(connection, server_context[:remote_ip], args, data, error, started)

        if error
          MCP::Tool::Response.new([{ type: 'text', text: error }], error: true)
        else
          MCP::Tool::Response.new([{ type: 'text', text: JSON.generate(data) }])
        end
      end

      private

      def read_only
        ActiveRecord::Base.transaction(requires_new: true) do
          conn = ActiveRecord::Base.connection
          conn.execute('SET TRANSACTION READ ONLY')
          conn.execute("SET LOCAL statement_timeout = '#{STATEMENT_TIMEOUT}'")
          yield
        end
      end

      def record(connection, remote_ip, args, data, error, started)
        GrokBotToolCall.create!(
          grok_bot_connection: connection,
          tool_name: tool_name,
          arguments: args,
          status: error ? 'error' : 'ok',
          error_message: error,
          result_count: data.is_a?(Hash) ? data[:count] : nil,
          duration_ms: ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round,
          remote_ip: remote_ip
        )
        connection.touch_usage!(remote_ip)
      rescue StandardError => e
        Rails.logger.error("[LsvMcp] could not record tool call: #{e.class}: #{e.message}")
      end
    end

    private

    def clamp_limit(value, default:, max:)
      value.nil? ? default : value.to_i.clamp(1, max)
    end

    def like_pattern(text)
      "%#{ActiveRecord::Base.sanitize_sql_like(text.to_s.strip)}%"
    end

    def clip(text, max = MAX_TEXT)
      text.is_a?(String) && text.length > max ? "#{text[0, max]}… [truncated, #{text.length} chars]" : text
    end

    def find_source!(code)
      Source.unscoped.find_by(code: code.to_s.strip.upcase) ||
        raise(Error, "Unknown source #{code.inspect}. Call list_sources for valid codes.")
    end

    # Accepts a book code (GEN, 1CO) or its standard name (Genesis), case-insensitively.
    def find_book!(code_or_name)
      value = code_or_name.to_s.strip
      Book.unscoped.find_by(code: value.upcase) ||
        Book.unscoped.where('lower(std_name) = lower(?)', value).first ||
        raise(Error, "Unknown book #{code_or_name.inspect}. Call list_books for valid codes.")
    end

    def verse_reference(text_content)
      "#{text_content.book.code} #{text_content.unit_group}:#{text_content.unit}"
    end
  end
end
