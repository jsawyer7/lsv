class FamiliesForFoundation < ApplicationRecord
  self.table_name = 'families_for_foundations'
  
  validates :code, presence: true, uniqueness: true
  validates :name, presence: true
  validates :domain, presence: true
  validates :display_order, presence: true, numericality: { only_integer: true }
  validates :is_active, inclusion: { in: [true, false] }
end
