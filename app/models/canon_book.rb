class CanonBook < ApplicationRecord
  belongs_to :canon
  belongs_to :book
  
  validates :canon, presence: true
  validates :book, presence: true
  validates :seq_no, presence: true, numericality: { greater_than: 0 }
  validates :included_bool, inclusion: { in: [true, false] }
  
  validates :book_id, uniqueness: { scope: :canon_id }
  
  scope :included, -> { where(included_bool: true) }
  scope :excluded, -> { where(included_bool: false) }
  scope :ordered, -> { order(:seq_no) }
  
  def display_name
    "#{book.std_name} (#{canon.name})"
  end

  def self.ransackable_attributes(auth_object = nil)
    ["book_id", "canon_id", "created_at", "description", "id", "included_bool", "seq_no", "updated_at"]
  end

  def self.ransackable_associations(auth_object = nil)
    ["book", "canon"]
  end
end
