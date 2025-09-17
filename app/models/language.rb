class Language < ApplicationRecord
  validates :code, presence: true, uniqueness: true
  validates :name, presence: true
  validates :iso_639_3, presence: true
  validates :script, presence: true
  validates :direction, presence: true
  validates :language_family, presence: true

  def self.ransackable_attributes(auth_object = nil)
    ["code", "created_at", "direction", "id", "iso_639_3", "language_family", "name", "notes", "script", "updated_at"]
  end
end
