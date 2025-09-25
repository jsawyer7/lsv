class FamiliesForFoundation < ApplicationRecord
  self.table_name = 'families_for_foundations'

  validates :code, presence: true, uniqueness: true
  validates :name, presence: true
  validates :domain, presence: true
  validates :display_order, presence: true, numericality: { only_integer: true }
  validates :is_active, inclusion: { in: [true, false] }

  def self.ransackable_attributes(auth_object = nil)
    ["code", "created_at", "description", "display_order", "domain", "id", "is_active", "name", "updated_at"]
  end
end
