class Reasoning < ApplicationRecord
  belongs_to :claim

  SOURCES = %w[Quran Tanakh Historical].freeze

  validates :source, presence: true, inclusion: { in: SOURCES }
  validates :response, presence: true
  validates :claim_id, uniqueness: { scope: :source }
end 