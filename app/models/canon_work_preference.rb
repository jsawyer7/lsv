class CanonWorkPreference < ApplicationRecord
  self.primary_key = [:canon_id, :work_code]

  belongs_to :canon
  belongs_to :master_book, foreign_key: 'work_code', primary_key: 'code'
  belongs_to :foundation, class_name: 'FoundationsOnly', foreign_key: 'foundation_code', primary_key: 'code'

  # Validations
  validates :foundation_code, presence: true
  validates :canon_id, presence: true
  validates :work_code, presence: true
  validates :canon_id, uniqueness: { scope: :work_code }

  scope :for_canon, ->(canon) { where(canon: canon) }
  scope :by_work_code, ->(code) { where(work_code: code) }

  def self.ransackable_attributes(auth_object = nil)
    ["canon_id", "created_at", "foundation_code", "notes", "numbering_system_code", "updated_at", "work_code"]
  end

  def self.ransackable_associations(auth_object = nil)
    ["canon"]
  end
end
