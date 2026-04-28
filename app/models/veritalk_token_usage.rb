class VeritalkTokenUsage < ApplicationRecord
  belongs_to :user
  belongs_to :conversation

  validates :input_tokens, numericality: { greater_than_or_equal_to: 0 }
  validates :output_tokens, numericality: { greater_than_or_equal_to: 0 }
  validates :total_tokens, numericality: { greater_than_or_equal_to: 0 }
  validates :used_at, presence: true

  scope :this_month, -> { where('used_at >= ?', Time.current.beginning_of_month) }

  before_validation :set_defaults
  before_validation :recalculate_total_tokens

  private

  def set_defaults
    self.used_at ||= Time.current
    self.input_tokens ||= 0
    self.output_tokens ||= 0
  end

  def recalculate_total_tokens
    self.total_tokens = input_tokens.to_i + output_tokens.to_i
  end
end
