class CanonMap < ApplicationRecord
  validates :canon_id, presence: true
  validates :unit_id, presence: true
  validates :sequence_index, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :canon_id, uniqueness: { scope: :unit_id }
  
  # Associations
  belongs_to :text_unit, foreign_key: 'unit_id', primary_key: 'unit_id'
  
  # Canonical identifiers for Quran
  QURAN_CANON_ID = 'quran_hafs_uthmani'
end
