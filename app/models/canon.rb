class Canon < ApplicationRecord
  validates :code, presence: true, uniqueness: true
  validates :name, presence: true
  validates :domain_code, presence: true
  validates :display_order, presence: true, numericality: { only_integer: true }
  validates :is_official, inclusion: { in: [true, false] }
  
  # Associations
  has_many :canon_book_inclusions, dependent: :destroy
  has_many :canon_work_preferences, dependent: :destroy
  
  # Through associations to master_books
  has_many :included_books, through: :canon_book_inclusions, source: :master_book
  has_many :preferred_books, through: :canon_work_preferences, source: :master_book
  
  # Domain association (assuming there's a domains table)
  # belongs_to :domain, foreign_key: 'domain_code', primary_key: 'code'
end
