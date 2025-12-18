class Conversation < ApplicationRecord
  belongs_to :user

  has_many :conversation_messages, dependent: :destroy
  has_many :conversation_summaries, dependent: :destroy

  validates :topic, presence: true
end
