class Direction < ApplicationRecord
  has_many :languages, dependent: :nullify
  
  validates :code, presence: true, uniqueness: true
  validates :name, presence: true
  
  scope :ordered, -> { order(:name) }
  
  def display_name
    "#{name} (#{code})"
  end

  def self.ransackable_attributes(auth_object = nil)
    ["code", "created_at", "description", "id", "name", "updated_at"]
  end

  def self.ransackable_associations(auth_object = nil)
    ["languages"]
  end
end
