class Theory < ApplicationRecord
  belongs_to :user
  has_many :likes, as: :likeable, dependent: :destroy
  has_many :comments, as: :commentable, dependent: :destroy
  has_many :shares, as: :shareable, dependent: :destroy

  validates :title, presence: true
  validates :description, presence: true
  validates :status, inclusion: { in: %w[in_review draft public] }
end
