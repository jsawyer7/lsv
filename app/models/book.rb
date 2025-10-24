class Book < ApplicationRecord
  has_many :canon_books, dependent: :destroy
  has_many :canons, through: :canon_books
  
  validates :code, presence: true, uniqueness: true
  validates :std_name, presence: true
  
  scope :ordered, -> { order(:std_name) }
  
  def display_name
    "#{std_name} (#{code})"
  end

  def self.ransackable_attributes(auth_object = nil)
    ["code", "created_at", "description", "id", "std_name", "updated_at"]
  end

  def self.ransackable_associations(auth_object = nil)
    ["canon_books", "canons"]
  end
end
