class MasterBook < ApplicationRecord
  validates :code, presence: true, uniqueness: true
  validates :title, presence: true
  validates :family_code, presence: true
  validates :origin_lang, presence: true
  
  # Canon associations
  has_many :canon_book_inclusions, foreign_key: 'work_code', primary_key: 'code', dependent: :destroy
  has_many :canon_work_preferences, foreign_key: 'work_code', primary_key: 'code', dependent: :destroy

  # Through associations to canons
  has_many :included_in_canons, through: :canon_book_inclusions, source: :canon
  has_many :preferred_in_canons, through: :canon_work_preferences, source: :canon

  scope :by_family, ->(family) { where(family_code: family) }
  scope :by_language, ->(lang) { where(origin_lang: lang) }

  def self.ransackable_attributes(auth_object = nil)
    ["code", "created_at", "family_code", "id", "notes", "origin_lang", "title", "updated_at"]
  end
end
