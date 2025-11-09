class CanonTextContent < ApplicationRecord
  belongs_to :text_content
  belongs_to :canon
  
  validates :text_content_id, uniqueness: { scope: :canon_id }
  
  def self.ransackable_attributes(auth_object = nil)
    ["canon_id", "created_at", "id", "text_content_id", "updated_at"]
  end
  
  def self.ransackable_associations(auth_object = nil)
    ["canon", "text_content"]
  end
end

