class NumberingSystem < ApplicationRecord
  validates :code, presence: true, uniqueness: true
  validates :name, presence: true

  # Associations
  has_many :numbering_labels, dependent: :destroy
  has_many :numbering_maps, dependent: :destroy

  # Ransack allowlist for Active Admin filtering
  def self.ransackable_attributes(auth_object = nil)
    ["code", "created_at", "description", "id", "name", "updated_at"]
  end

  def self.ransackable_associations(auth_object = nil)
    ["numbering_labels", "numbering_maps"]
  end
end
