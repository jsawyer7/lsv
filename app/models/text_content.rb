class TextContent < ApplicationRecord
  belongs_to :source
  belongs_to :book
  belongs_to :text_unit_type
  belongs_to :language
  belongs_to :parent_unit, class_name: 'TextContent', optional: true
  belongs_to :addressed_party, class_name: 'PartyType', foreign_key: 'addressed_party_code', primary_key: 'code', optional: true
  belongs_to :responsible_party, class_name: 'PartyType', foreign_key: 'responsible_party_code', primary_key: 'code', optional: true
  belongs_to :genre, class_name: 'GenreType', foreign_key: 'genre_code', primary_key: 'code', optional: true
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
    
    # Handle new structure: { tokens: [...], lsv_notes: {...} }
    if word_for_word_translation.is_a?(Hash) && word_for_word_translation['tokens']
      return word_for_word_translation['tokens'] || []
    end
    
    # Handle old structure: direct array
    word_for_word_translation.is_a?(Array) ? word_for_word_translation : []
  end
  
  def lsv_notes
    return {} if word_for_word_translation.blank?
    
    # Handle new structure: { tokens: [...], lsv_notes: {...} }
    if word_for_word_translation.is_a?(Hash) && word_for_word_translation['lsv_notes']
      return word_for_word_translation['lsv_notes'] || {}
    end
    
    # Old structure doesn't have lsv_notes
    {}
  end

  def content_populated?
    content_populated_at.present? && content.present?
  end

  def population_pending?
    population_status == 'pending' || population_status.nil?
  end

  def population_success?
    population_status == 'success'
  end

  def population_error?
    population_status == 'error'
  end

  def population_unavailable?
    population_status == 'unavailable'
  end

  def content_validated?
    content_validated_at.present? && content_validation_result.present?
  end

  def is_100_percent_accurate?
    return false unless content_validated?
    content_validation_result['is_accurate'] == true
  end

  def validation_accuracy_percentage
    return nil unless content_validated?
    content_validation_result['accuracy_percentage'] || 0
  end

  def validation_discrepancies
    return [] unless content_validated?
    content_validation_result['discrepancies'] || []
  end

  def validation_character_accurate?
    return nil unless content_validated?
    content_validation_result['character_accurate'] == true
  end

  def validation_lexical_coverage_complete?
    return nil unless content_validated?
    content_validation_result['lexical_coverage_complete'] != false
  end

  def validation_lsv_translation_valid?
    return nil unless content_validated?
    content_validation_result['lsv_translation_valid'] != false
  end

  def validation_lexical_coverage_issues
    return [] unless content_validated?
    content_validation_result['lexical_coverage_issues'] || []
  end

  def validation_lsv_translation_issues
    return [] unless content_validated?
    content_validation_result['lsv_translation_issues'] || []
  end

  def validation_flags
    return [] unless content_validated?
    content_validation_result['validation_flags'] || []
  end

  def self.ransackable_attributes(auth_object = nil)
    ["book_id", "unit_group", "content", "created_at", "id", "language_id", "parent_unit_id", 
     "source_id", "text_unit_type_id", "unit_key", "unit", "updated_at", "word_for_word_translation",
     "lsv_literal_reconstruction", "addressed_party_code", "responsible_party_code", "genre_code"]
  end

  def self.ransackable_associations(auth_object = nil)
    ["book", "canon_text_contents", "canons", "child_units", "language", "parent_unit", "source", "text_unit_type",
     "addressed_party", "responsible_party", "genre"]
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
