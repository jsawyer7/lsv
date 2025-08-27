class CanonBookInclusion < ApplicationRecord
  validates :canon_id, presence: true
  validates :work_code, presence: true
  validates :work_code, uniqueness: { scope: :canon_id }
  
  # Associations
  belongs_to :canon
  belongs_to :master_book, foreign_key: 'work_code', primary_key: 'code'
  
  # Validations for range fields
  validates :include_from, presence: true
  # include_to can be nil (meaning include the entire work)
  # notes can be nil
end
