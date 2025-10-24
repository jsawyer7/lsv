class Source < ApplicationRecord
  belongs_to :language
  
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

  def self.ransackable_attributes(auth_object = nil)
    ["code", "created_at", "description", "id", "language_id", "name", "provenance", "rights_json", "updated_at"]
  end

  def self.ransackable_associations(auth_object = nil)
    ["language"]
  end
end
