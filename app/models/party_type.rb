class PartyType < ApplicationRecord
  self.primary_key = 'code'
  
  has_many :addressed_text_contents, class_name: 'TextContent', foreign_key: 'addressed_party_code', primary_key: 'code'
  has_many :responsible_text_contents, class_name: 'TextContent', foreign_key: 'responsible_party_code', primary_key: 'code'
  
  validates :code, presence: true, uniqueness: true
  validates :label, presence: true
  
  default_scope { order(:code) }
  
  scope :ordered, -> { order(:code) }
  
  def display_name
    label
  end
end

