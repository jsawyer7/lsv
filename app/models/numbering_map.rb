class NumberingMap < ApplicationRecord
  validates :numbering_system_id, presence: true
  validates :unit_id, presence: true
  validates :work_code, presence: true
  validates :numbering_system_id, uniqueness: { scope: :unit_id }

  # Associations
  belongs_to :numbering_system
  belongs_to :master_book, foreign_key: 'work_code', primary_key: 'code'

  # Ransack allowlist for Active Admin filtering
  def self.ransackable_attributes(auth_object = nil)
    ["created_at", "id", "l1", "l2", "l3", "n_book", "n_chapter", "n_sub", "n_verse", "numbering_system_id", "status", "unit_id", "updated_at", "work_code"]
  end

  def self.ransackable_associations(auth_object = nil)
    ["numbering_system", "master_book"]
  end
end
