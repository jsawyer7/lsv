class Comment < ApplicationRecord
  belongs_to :user
  belongs_to :commentable, polymorphic: true
  has_many :likes, as: :likeable, dependent: :destroy

  validates :content, presence: true, length: { maximum: 5000 }

  scope :recent, -> { order(created_at: :desc) }
end
