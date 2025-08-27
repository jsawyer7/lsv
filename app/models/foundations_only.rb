class FoundationsOnly < ApplicationRecord
  self.table_name = 'foundations_only'
  
  validates :code, presence: true, uniqueness: true
  validates :title, presence: true
  validates :tradition_code, presence: true
  validates :lang_code, presence: true
  validates :scope, presence: true
  validates :is_active, inclusion: { in: [true, false] }
end
