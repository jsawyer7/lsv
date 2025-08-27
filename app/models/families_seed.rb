class FamiliesSeed < ApplicationRecord
  self.table_name = 'families_seed'
  
  validates :code, presence: true, uniqueness: true
  validates :name, presence: true
end
