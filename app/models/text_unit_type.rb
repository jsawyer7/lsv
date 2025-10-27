class TextUnitType < ApplicationRecord
  has_many :text_contents, dependent: :destroy
  
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
    ["text_contents"]
  end
end
