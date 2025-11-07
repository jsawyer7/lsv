class TextContent < ApplicationRecord
  belongs_to :source
  belongs_to :book
  belongs_to :text_unit_type
  belongs_to :language
  belongs_to :parent_unit, class_name: 'TextContent', optional: true
  has_many :child_units, class_name: 'TextContent', foreign_key: 'parent_unit_id', dependent: :destroy
  has_many :text_translations, dependent: :destroy
  
  validates :source, presence: true
  validates :book, presence: true
  validates :text_unit_type, presence: true
  validates :language, presence: true
  validates :content, presence: true, unless: :allow_empty_content?
  validates :unit_key, presence: true, uniqueness: { scope: [:source_id, :book_id] }
  
  attr_accessor :allow_empty_content
  
  # Canon validations
  validates :canon_catholic, inclusion: { in: [true, false] }
  validates :canon_protestant, inclusion: { in: [true, false] }
  validates :canon_lutheran, inclusion: { in: [true, false] }
  validates :canon_anglican, inclusion: { in: [true, false] }
  validates :canon_greek_orthodox, inclusion: { in: [true, false] }
  validates :canon_russian_orthodox, inclusion: { in: [true, false] }
  validates :canon_georgian_orthodox, inclusion: { in: [true, false] }
  validates :canon_western_orthodox, inclusion: { in: [true, false] }
  validates :canon_coptic, inclusion: { in: [true, false] }
  validates :canon_armenian, inclusion: { in: [true, false] }
  validates :canon_ethiopian, inclusion: { in: [true, false] }
  validates :canon_syriac, inclusion: { in: [true, false] }
  validates :canon_church_east, inclusion: { in: [true, false] }
  validates :canon_judaic, inclusion: { in: [true, false] }
  validates :canon_samaritan, inclusion: { in: [true, false] }
  validates :canon_lds, inclusion: { in: [true, false] }
  validates :canon_quran, inclusion: { in: [true, false] }
  
  before_validation :normalize_content_and_punctuation
  
  scope :by_source, ->(source_id) { where(source_id: source_id) }
  scope :by_book, ->(book_id) { where(book_id: book_id) }
  scope :by_text_unit_type, ->(text_unit_type_id) { where(text_unit_type_id: text_unit_type_id) }
  scope :by_language, ->(language_id) { where(language_id: language_id) }
  scope :by_canon, ->(canon_name) { where("#{canon_name}" => true) }
  scope :ordered, -> { order(:unit_key) }
  
  def display_name
    "#{book.std_name} - #{text_unit_type.name} - #{unit_key}"
  end
  
  # Mapping from Canon table codes to TextContent canon fields
  # This maps what codes exist in your canons table to the TextContent boolean fields
  CODE_TO_CANON_FIELD = {
    'CATH' => :canon_catholic,
    'PROT' => :canon_protestant,
    'ETH' => :canon_ethiopian,
    'JEW' => :canon_judaic,
    'ORTH' => :canon_greek_orthodox,
    # Add more mappings as you add canons
    'CHR_LUTHERAN' => :canon_lutheran,
    'CHR_ANGLICAN' => :canon_anglican,
    'CHR_GREEK_ORTH' => :canon_greek_orthodox,
    'CHR_RUSSIAN_ORTH' => :canon_russian_orthodox,
    'CHR_GEORGIAN_ORTH' => :canon_georgian_orthodox,
    'CHR_WESTERN_ORTH' => :canon_western_orthodox,
    'CHR_COPTIC' => :canon_coptic,
    'CHR_ARMENIAN' => :canon_armenian,
    'CHR_ETHIOPIAN' => :canon_ethiopian,
    'CHR_SYRIAC' => :canon_syriac,
    'CHR_CHURCH_EAST' => :canon_church_east,
    'HEB_SAMARITAN' => :canon_samaritan,
    'CHR_LDS' => :canon_lds,
    'ISL_QURAN' => :canon_quran
  }.freeze

  # Reverse mapping for display
  CANON_FIELD_TO_CODE = CODE_TO_CANON_FIELD.invert.freeze

  def canon_list
    canons = []
    CODE_TO_CANON_FIELD.each do |code, field|
      if send(field)
        canon = Canon.find_by(code: code)
        canons << (canon ? canon.name : code)
      end
    end
    canons.join(", ")
  end

  def word_for_word_array
    return [] if word_for_word_translation.blank?
    word_for_word_translation.is_a?(Array) ? word_for_word_translation : []
  end

  def self.ransackable_attributes(auth_object = nil)
    ["book_id", "canon_anglican", "canon_armenian", "canon_catholic", "canon_church_east", 
     "canon_coptic", "canon_ethiopian", "canon_georgian_orthodox", "canon_greek_orthodox", 
     "canon_judaic", "canon_lds", "canon_lutheran", "canon_protestant", "canon_quran", 
     "canon_russian_orthodox", "canon_samaritan", "canon_syriac", "canon_western_orthodox", 
     "unit_group", "content", "created_at", "id", "language_id", "parent_unit_id", 
     "source_id", "text_unit_type_id", "unit_key", "unit", "updated_at", "word_for_word_translation",
     "lsv_literal_reconstruction"]
  end

  def self.ransackable_associations(auth_object = nil)
    ["book", "child_units", "language", "parent_unit", "source", "text_unit_type"]
  end

  private

  def allow_empty_content?
    allow_empty_content == true
  end

  def normalize_content_and_punctuation
    return if content.nil? || content.blank?

    normalized = content.to_s.strip
    return if normalized.empty? # Allow empty content for initial creation

    normalized = normalized.unicode_normalize(:nfc)
    # Normalize Greek punctuation
    normalized = normalized.gsub(";", "\u037E") # Greek question mark
    normalized = normalized.gsub("\u00B7", "\u0387") # Greek ano teleia
    # Collapse internal whitespace
    normalized = normalized.gsub(/\s+/, ' ')
    self.content = normalized
  end
end
