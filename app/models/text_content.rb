class TextContent < ApplicationRecord
  belongs_to :source
  belongs_to :book
  belongs_to :text_unit_type
  belongs_to :language
  belongs_to :parent_unit, class_name: 'TextContent', optional: true
  has_many :child_units, class_name: 'TextContent', foreign_key: 'parent_unit_id', dependent: :destroy
  
  validates :source, presence: true
  validates :book, presence: true
  validates :text_unit_type, presence: true
  validates :language, presence: true
  validates :content, presence: true
  validates :unit_key, presence: true, uniqueness: true
  
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
  
  scope :by_source, ->(source_id) { where(source_id: source_id) }
  scope :by_book, ->(book_id) { where(book_id: book_id) }
  scope :by_text_unit_type, ->(text_unit_type_id) { where(text_unit_type_id: text_unit_type_id) }
  scope :by_language, ->(language_id) { where(language_id: language_id) }
  scope :by_canon, ->(canon_name) { where("#{canon_name}" => true) }
  scope :ordered, -> { order(:unit_key) }
  
  def display_name
    "#{book.std_name} - #{text_unit_type.name} - #{unit_key}"
  end
  
  def canon_list
    canons = []
    canons << "Catholic" if canon_catholic
    canons << "Protestant" if canon_protestant
    canons << "Lutheran" if canon_lutheran
    canons << "Anglican" if canon_anglican
    canons << "Greek Orthodox" if canon_greek_orthodox
    canons << "Russian Orthodox" if canon_russian_orthodox
    canons << "Georgian Orthodox" if canon_georgian_orthodox
    canons << "Western Orthodox" if canon_western_orthodox
    canons << "Coptic" if canon_coptic
    canons << "Armenian" if canon_armenian
    canons << "Ethiopian" if canon_ethiopian
    canons << "Syriac" if canon_syriac
    canons << "Church of the East" if canon_church_east
    canons << "Judaic" if canon_judaic
    canons << "Samaritan" if canon_samaritan
    canons << "LDS" if canon_lds
    canons << "Quran" if canon_quran
    canons.join(", ")
  end

  def self.ransackable_attributes(auth_object = nil)
    ["book_id", "canon_anglican", "canon_armenian", "canon_catholic", "canon_church_east", 
     "canon_coptic", "canon_ethiopian", "canon_georgian_orthodox", "canon_greek_orthodox", 
     "canon_judaic", "canon_lds", "canon_lutheran", "canon_protestant", "canon_quran", 
     "canon_russian_orthodox", "canon_samaritan", "canon_syriac", "canon_western_orthodox", 
     "chapter_number", "content", "created_at", "id", "language_id", "parent_unit_id", 
     "source_id", "text_unit_type_id", "unit_key", "unit_number", "updated_at", "verse_number"]
  end

  def self.ransackable_associations(auth_object = nil)
    ["book", "child_units", "language", "parent_unit", "source", "text_unit_type"]
  end
end
