class NumberingSystem < ApplicationRecord
  validates :code, presence: true, uniqueness: true
  validates :name, presence: true
  
  # Associations
  has_many :numbering_labels, dependent: :destroy
  has_many :numbering_maps, dependent: :destroy
end
