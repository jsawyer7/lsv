class Canon < ApplicationRecord
  has_many :canon_books, dependent: :destroy
  has_many :books, through: :canon_books
  has_many :canon_text_contents, dependent: :destroy
  has_many :text_contents, through: :canon_text_contents
  
  validates :code, presence: true, uniqueness: true
  validates :name, presence: true
  
  default_scope { order(created_at: :asc) }
  scope :ordered, -> { order(:name) }
  
  def display_name
    "#{name} (#{code})"
  end
  
  def included_books
    canon_books.where(included_bool: true).order(:seq_no)
  end

  def self.ransackable_attributes(auth_object = nil)
    ["code", "created_at", "description", "id", "name", "updated_at"]
  end

  def self.ransackable_associations(auth_object = nil)
    ["canon_books", "books", "canon_text_contents", "text_contents"]
  end
end
