# Audit log: one row per MCP tool call, initialize or tools/list request made with a GrokBotConnection.
class GrokBotToolCall < ApplicationRecord
  STATUSES = %w[ok error].freeze

  belongs_to :grok_bot_connection

  validates :tool_name, :duration_ms, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :recent, -> { order(created_at: :desc) }
end
