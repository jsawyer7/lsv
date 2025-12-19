class ConversationSummary < ApplicationRecord
  belongs_to :conversation

  validates :content, presence: true
  validates :position, presence: true

  before_validation :assign_position, on: :create

  default_scope { order(position: :asc) }

  def self.ransackable_attributes(auth_object = nil)
    %w[id conversation_id content position created_at updated_at]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[conversation]
  end

  private

  def assign_position
    return if position.present? || conversation.blank?

    max_position = conversation.conversation_summaries.maximum(:position) || 0
    self.position = max_position + 1
  end
end
