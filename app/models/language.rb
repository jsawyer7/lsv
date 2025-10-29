class Language < ApplicationRecord
  belongs_to :direction, optional: true
  has_many :sources, dependent: :destroy
  
  validates :code, presence: true, uniqueness: true
  validates :name, presence: true
  
  scope :ordered, -> { order(:name) }
  scope :by_direction, ->(direction_id) { where(direction_id: direction_id) }
  scope :ltr_languages, -> { joins(:direction).where(directions: { code: 'LTR' }) }
  scope :rtl_languages, -> { joins(:direction).where(directions: { code: 'RTL' }) }
  
  def display_name
    "#{name} (#{code})"
  end

  def direction_name
    direction&.name
  end

  def direction_code
    direction&.code
  end

  def is_rtl?
    direction_code == 'RTL'
  end

  def is_ltr?
    direction_code == 'LTR'
  end

  def font_stack_array
    font_stack.present? ? font_stack.split(',').map(&:strip) : []
  end

  def self.ransackable_attributes(auth_object = nil)
    ["code", "created_at", "description", "direction_id", "font_stack", "has_ayah_markers", 
     "has_cantillation", "has_joining", "id", "name", "native_digits", "punctuation_mirroring", 
     "script", "shaping_engine", "unicode_normalization", "updated_at", "uses_diacritics"]
  end

  def self.ransackable_associations(auth_object = nil)
    ["direction", "sources"]
  end
end
