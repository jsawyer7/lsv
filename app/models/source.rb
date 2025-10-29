class Source < ApplicationRecord
  belongs_to :language
  belongs_to :text_unit_type, optional: true
  
  validates :code, presence: true, uniqueness: true
  validates :name, presence: true
  validates :language, presence: true
  
  scope :ordered, -> { order(:name) }
  scope :by_language, ->(language_id) { where(language_id: language_id) }
  
  def display_name
    "#{name} (#{code})"
  end
  
  def language_name
    language&.name
  end

  def text_unit_type_name
    text_unit_type&.name
  end

  def self.ransackable_attributes(auth_object = nil)
    ["code", "created_at", "description", "id", "language_id", "name", "provenance", "rights_json", "text_unit_type_id", "updated_at"]
  end

  def self.ransackable_associations(auth_object = nil)
    ["language", "text_unit_type"]
  end
end
