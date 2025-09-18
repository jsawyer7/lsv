class NumberingMap < ApplicationRecord
  validates :numbering_system_id, presence: true
  validates :unit_id, presence: true
  validates :work_code, presence: true
  validates :numbering_system_id, uniqueness: { scope: :unit_id }
  
  # Associations
  belongs_to :numbering_system
  belongs_to :master_book, foreign_key: 'work_code', primary_key: 'code'
end
