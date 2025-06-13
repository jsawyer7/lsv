class Theory < ApplicationRecord
  belongs_to :user
  validates :title, presence: true
  validates :description, presence: true
  validates :status, inclusion: { in: %w[in_review draft public] }
end 