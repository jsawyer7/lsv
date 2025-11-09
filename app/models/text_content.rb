class TextContent < ApplicationRecord
  belongs_to :source
  belongs_to :book
  belongs_to :text_unit_type
  belongs_to :language
  belongs_to :parent_unit, class_name: 'TextContent', optional: true
  has_many :child_units, class_name: 'TextContent', foreign_key: 'parent_unit_id', dependent: :destroy
  has_many :text_translations, dependent: :destroy
  has_many :canon_text_contents, dependent: :destroy
  has_many :canons, through: :canon_text_contents
  
  validates :source, presence: true
  validates :book, presence: true
  validates :text_unit_type, presence: true
  validates :language, presence: true
  # Content validation removed - allow blank content for editing
  validates :unit_key, presence: true, uniqueness: { scope: [:source_id, :book_id] }
  
  attr_accessor :allow_empty_content
  
  before_validation :normalize_content_and_punctuation
  
  default_scope { order(created_at: :asc) }
  
  scope :by_source, ->(source_id) { where(source_id: source_id) }
  scope :by_book, ->(book_id) { where(book_id: book_id) }
  scope :by_text_unit_type, ->(text_unit_type_id) { where(text_unit_type_id: text_unit_type_id) }
  scope :by_language, ->(language_id) { where(language_id: language_id) }
  scope :by_canon, ->(canon_id) { joins(:canons).where(canons: { id: canon_id }) }
  scope :ordered, -> { order(:unit_key) }
  scope :ordered_by_created_at, -> { order(created_at: :desc) }
  
  def display_name
    "#{book.std_name} - #{text_unit_type.name} - #{unit_key}"
  end
  
  def canon_list
    canons.pluck(:name).join(", ")
  end

  def word_for_word_array
    return [] if word_for_word_translation.blank?
    word_for_word_translation.is_a?(Array) ? word_for_word_translation : []
  end

  def self.ransackable_attributes(auth_object = nil)
    ["book_id", "unit_group", "content", "created_at", "id", "language_id", "parent_unit_id", 
     "source_id", "text_unit_type_id", "unit_key", "unit", "updated_at", "word_for_word_translation",
     "lsv_literal_reconstruction"]
  end

  def self.ransackable_associations(auth_object = nil)
    ["book", "canon_text_contents", "canons", "child_units", "language", "parent_unit", "source", "text_unit_type"]
  end

  private

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
