class NumberingLabel < ApplicationRecord
  validates :numbering_system_id, presence: true
  validates :system_code, presence: true
  validates :label, presence: true
  validates :numbering_system_id, uniqueness: { scope: :system_code }
  
  # Associations
  belongs_to :numbering_system
end
