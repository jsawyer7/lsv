# A single word of a source text (MorphGNT SBLGNT, OSHB Hebrew OT), stored
# verbatim from the source file together with its morphology. Not AI-generated.
# kind: 'word', or for the Hebrew OT 'ketiv' (written) / 'qere' (read) forms.
class TextContentToken < ApplicationRecord
  belongs_to :text_content

  KINDS = %w[word ketiv qere].freeze

  # pos/normalized exist only for sources that provide them (MorphGNT).
  validates :position, :ref, :surface, :word, :lemma, :parsing, presence: true
  validates :kind, inclusion: { in: KINDS }
  validates :position, uniqueness: { scope: :text_content_id }

  default_scope { order(:text_content_id, :position) }

  def self.ransackable_attributes(_auth_object = nil)
    %w[id text_content_id position ref surface word normalized lemma pos parsing kind source_word_id source_n]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[text_content]
  end
end
