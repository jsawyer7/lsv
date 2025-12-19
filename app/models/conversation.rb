class Conversation < ApplicationRecord
  belongs_to :user

  has_many :conversation_messages, dependent: :destroy
  has_many :conversation_summaries, dependent: :destroy

  validates :topic, presence: true

  def self.ransackable_attributes(auth_object = nil)
    %w[id topic summary user_id created_at updated_at]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[user conversation_messages conversation_summaries]
  end
end
