class FamiliesSeed < ApplicationRecord
  self.table_name = 'families_seed'

  validates :code, presence: true, uniqueness: true
  validates :name, presence: true

  def self.ransackable_attributes(auth_object = nil)
    ["code", "created_at", "id", "name", "notes", "updated_at"]
  end
end
