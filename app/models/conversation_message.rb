class ConversationMessage < ApplicationRecord
  ROLES = %w[user assistant].freeze

  belongs_to :conversation

  validates :role, presence: true, inclusion: { in: ROLES }
  validates :content, presence: true
  validates :position, presence: true

  before_validation :assign_position, on: :create

  default_scope { order(position: :asc) }

  private

  def assign_position
    return if position.present? || conversation.blank?

    max_position = conversation.conversation_messages.maximum(:position) || 0
    self.position = max_position + 1
  end
end
