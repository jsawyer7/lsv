class Evidence < ApplicationRecord
  belongs_to :claim
  has_many :challenges, dependent: :destroy

  enum source: {
    quran: 0,
    tanakh: 1,
    catholic: 2,
    ethiopian: 3,
    protestant: 4,
    historical: 5
  }

  # Add methods to handle multiple sources
  def source_names
    sources.map { |s| self.class.sources.key(s) }.compact
  end

  def add_source(source_name)
    source_enum = self.class.sources[source_name]
    return unless source_enum
    self.sources = (sources + [source_enum]).uniq
  end

  def remove_source(source_name)
    source_enum = self.class.sources[source_name]
    return unless source_enum
    self.sources = sources - [source_enum]
  end

  def has_source?(source_name)
    source_enum = self.class.sources[source_name]
    return false unless source_enum
    sources.include?(source_enum)
  end
end
