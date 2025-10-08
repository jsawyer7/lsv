class CanonMap < ApplicationRecord
  # Since this table has no id column, we need to handle primary key differently
  # We'll use a virtual primary key approach for ActiveAdmin compatibility
  self.primary_key = 'canon_id'

  validates :canon_id, presence: true
  validates :unit_id, presence: true
  validates :sequence_index, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :canon_id, uniqueness: { scope: :unit_id }

  # Associations
  belongs_to :text_unit, foreign_key: 'unit_id', primary_key: 'unit_id'

  # Canonical identifiers for Quran
  QURAN_CANON_ID = 'quran_hafs_uthmani'

  def self.ransackable_attributes(auth_object = nil)
    ["canon_id", "unit_id", "sequence_index", "created_at", "updated_at"]
  end

  def self.ransackable_associations(auth_object = nil)
    ["text_unit"]
  end

  # Override model_name to provide custom display name for Active Admin
  def self.model_name
    @model_name ||= ActiveModel::Name.new(self, nil, "CanonMap")
  end

  # Override id method to return canon_id for ActiveAdmin compatibility
  def id
    canon_id
  end

  # Custom method to generate a unique identifier for Active Admin
  def to_param
    "#{canon_id}|#{unit_id}"
  end

  # Custom finder method for Active Admin
  def self.find_by_param(param)
    canon_id, unit_id = param.split('|', 2)
    find_by(canon_id: canon_id, unit_id: unit_id)
  end

  # Override find method to handle our custom primary key
  def self.find(id)
    if id.include?('|')
      find_by_param(id)
    else
      find_by(canon_id: id)
    end
  end
end
