class Theory < ApplicationRecord
  belongs_to :user
  has_many :likes, as: :likeable, dependent: :destroy

  validates :title, presence: true
  validates :description, presence: true
  validates :status, inclusion: { in: %w[in_review draft public] }
end
