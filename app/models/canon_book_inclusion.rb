class CanonBookInclusion < ApplicationRecord
  self.primary_key = [:canon_id, :work_code]

  belongs_to :canon
  belongs_to :master_book, foreign_key: 'work_code', primary_key: 'code'

  # Validations for range fields
  validates :include_from, presence: true
  validates :canon_id, presence: true
  validates :work_code, presence: true
  validates :canon_id, uniqueness: { scope: :work_code }

  scope :for_canon, ->(canon) { where(canon: canon) }
  scope :by_work_code, ->(code) { where(work_code: code) }

  def self.ransackable_attributes(auth_object = nil)
    ["canon_id", "created_at", "include_from", "include_to", "notes", "updated_at", "work_code"]
  end

  def self.ransackable_associations(auth_object = nil)
    ["canon"]
  end
end
