class VeritalkValidator < ApplicationRecord
  PURPOSE_FORENSIC = "forensic"
  PURPOSE_CONVERSATIONAL = "conversational"
  PURPOSES = [PURPOSE_FORENSIC, PURPOSE_CONVERSATIONAL].freeze

  # Polymorphic association - can be created by User or Admin
  belongs_to :created_by, polymorphic: true, optional: true

  validates :name, presence: true
  validates :system_prompt, presence: true
  validates :version, presence: true, numericality: { greater_than: 0 }
  validates :purpose, presence: true, inclusion: { in: PURPOSES }

  before_save :ensure_single_active_for_purpose, if: :is_active?

  scope :active, -> { where(is_active: true) }
  scope :inactive, -> { where(is_active: false) }
  scope :latest, -> { order(version: :desc, created_at: :desc) }
  scope :forensic_validators, -> { where(purpose: PURPOSE_FORENSIC) }
  scope :conversational_validators, -> { where(purpose: PURPOSE_CONVERSATIONAL) }

  def self.current
    current_forensic
  end

  def self.current_forensic
    active.forensic_validators.first || forensic_validators.latest.first
  end

  def self.current_conversational
    active.conversational_validators.first || conversational_validators.latest.first
  end

  def activate!
    transaction do
      VeritalkValidator.where(purpose: purpose).where.not(id: id).update_all(is_active: false)
      update!(is_active: true)
    end
  end

  def deactivate!
    update!(is_active: false)
  end

  def self.ransackable_attributes(auth_object = nil)
    %w[id name description purpose is_active version created_at updated_at]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[created_by]
  end

  private

  def ensure_single_active_for_purpose
    return unless is_active? && (is_active_changed? || purpose_changed?)

    VeritalkValidator.where(purpose: purpose).where.not(id: id).update_all(is_active: false)
  end
end
