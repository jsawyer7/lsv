class TextPayload < ApplicationRecord
  self.primary_key = 'payload_id'
  
  validates :payload_id, presence: true, uniqueness: true
  validates :unit_id, presence: true
  validates :language, presence: true
  validates :script, presence: true
  validates :edition_id, presence: true
  validates :layer, presence: true
  validates :content, presence: true
  validates :checksum_sha256, presence: true, format: { with: /\A[a-f0-9]{64}\z/i }
  validates :source_id, presence: true
  validates :license, presence: true
  validates :unit_id, uniqueness: { scope: [:edition_id, :layer, :language] }
  
  # Associations
  belongs_to :text_unit, foreign_key: 'unit_id', primary_key: 'unit_id'
  belongs_to :source_registry, foreign_key: 'source_id', primary_key: 'source_id'
  
  # Canonical identifiers for Quran
  QURAN_LANGUAGE = 'ara'
  QURAN_SCRIPT = 'Arab'
  QURAN_EDITION_ID = 'Quran_Hafs_Uthmani_Tanzil'
  QURAN_LAYER = 'source_text'
  QURAN_LICENSE = 'CC BY 3.0'
  
  # Generate SHA-256 checksum for content
  def self.generate_checksum(content)
    require 'digest'
    Digest::SHA256.hexdigest(content)
  end
  
  # Normalize Arabic text to Unicode NFC
  def self.normalize_arabic(text)
    text.unicode_normalize(:nfc)
  end
  
  # Validate checksum against content
  def verify_checksum
    self.class.generate_checksum(content) == checksum_sha256
  end
end
