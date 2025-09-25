class NumberingLabel < ApplicationRecord
  validates :numbering_system_id, presence: true
  validates :system_code, presence: true
  validates :label, presence: true
  validates :numbering_system_id, uniqueness: { scope: :system_code }

  # Associations
  belongs_to :numbering_system

  # Ransack allowlist for Active Admin filtering
  def self.ransackable_attributes(auth_object = nil)
    ["applies_to", "created_at", "description", "id", "label", "locale", "numbering_system_id", "system_code", "updated_at"]
  end

  def self.ransackable_associations(auth_object = nil)
    ["numbering_system"]
  end
end
