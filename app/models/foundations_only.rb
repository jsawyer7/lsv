class FoundationsOnly < ApplicationRecord
  self.table_name = 'foundations_only'

  validates :code, presence: true, uniqueness: true
  validates :title, presence: true
  validates :tradition_code, presence: true
  validates :lang_code, presence: true
  validates :scope, presence: true
  validates :pub_range, presence: true
  validates :is_active, inclusion: { in: [true, false] }
   # Canon associations
   has_many :canon_work_preferences, foreign_key: 'foundation_code', primary_key: 'code', dependent: :destroy


  scope :active, -> { where(is_active: true) }
  scope :by_tradition, ->(tradition) { where(tradition_code: tradition) }
  scope :by_language, ->(lang) { where(lang_code: lang) }

  def self.ransackable_attributes(auth_object = nil)
    ["citation_hint", "code", "created_at", "id", "is_active", "lang_code", "pub_range", "scope", "title", "tradition_code", "updated_at"]
  end
end
