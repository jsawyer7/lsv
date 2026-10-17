# A single word of a source text (e.g. MorphGNT SBLGNT), stored verbatim from
# the source file together with its morphology. Not AI-generated.
class TextContentToken < ApplicationRecord
  belongs_to :text_content

  validates :position, :ref, :surface, :word, :normalized, :lemma, :pos, :parsing, presence: true
  validates :position, uniqueness: { scope: :text_content_id }

  default_scope { order(:text_content_id, :position) }

  def self.ransackable_attributes(_auth_object = nil)
    %w[id text_content_id position ref surface word normalized lemma pos parsing]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[text_content]
  end
end
