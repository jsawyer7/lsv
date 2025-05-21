class Reasoning < ApplicationRecord
  belongs_to :reasonable, polymorphic: true

  SOURCES = %w[Quran Tanakh Historical].freeze

  validates :source, presence: true, inclusion: { in: SOURCES }
  validates :response, presence: true
  validates :reasonable_id, uniqueness: { scope: [:reasonable_type, :source] }
end 