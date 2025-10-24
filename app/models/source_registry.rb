class SourceRegistry < ApplicationRecord
  self.primary_key = 'source_id'

  validates :source_id, presence: true, uniqueness: true
  validates :name, presence: true
  validates :checksum_sha256, presence: true, format: { with: /\A[a-f0-9]{64}\z/i }

  # Associations
  has_many :text_payloads, foreign_key: 'source_id', primary_key: 'source_id', dependent: :restrict_with_error

  # Tanzil source information
  TANZIL_SOURCE = {
    name: 'Tanzil Uthmani',
    publisher: 'Tanzil Project',
    contact: 'https://tanzil.net/',
    license: 'CC BY 3.0',
    url: 'https://tanzil.net/',
    version: '1.0'
  }.freeze

  def self.ransackable_attributes(auth_object = nil)
    ["source_id", "name", "publisher", "contact", "license", "url", "version", "checksum_sha256", "notes", "created_at", "updated_at"]
  end

  def self.ransackable_associations(auth_object = nil)
    ["text_payloads"]
  end
end
