class GenreType < ApplicationRecord
  self.primary_key = 'code'
  
  has_many :text_contents, foreign_key: 'genre_code', primary_key: 'code'
  
  validates :code, presence: true, uniqueness: true
  validates :label, presence: true
  
  default_scope { order(:code) }
  
  scope :ordered, -> { order(:code) }
  
  def display_name
    label
  end
end

