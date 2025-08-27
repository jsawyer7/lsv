class CanonWorkPreference < ApplicationRecord
  validates :canon_id, presence: true
  validates :work_code, presence: true
  validates :work_code, uniqueness: { scope: :canon_id }
  
  # Associations
  belongs_to :canon
  belongs_to :master_book, foreign_key: 'work_code', primary_key: 'code'
  belongs_to :foundation, class_name: 'FoundationsOnly', foreign_key: 'foundation_code', primary_key: 'code'
  
  # Validations
  validates :foundation_code, presence: true
  # numbering_system_code can be nil in Phase 1
  # notes can be nil
end
