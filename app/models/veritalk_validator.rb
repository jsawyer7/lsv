class VeritalkValidator < ApplicationRecord
  # Polymorphic association - can be created by User or Admin
  belongs_to :created_by, polymorphic: true, optional: true

  validates :name, presence: true
  validates :system_prompt, presence: true
  validates :version, presence: true, numericality: { greater_than: 0 }

  # Ensure only one active validator at a time
  before_save :ensure_single_active, if: :is_active?

  scope :active, -> { where(is_active: true) }
  scope :inactive, -> { where(is_active: false) }
  scope :latest, -> { order(version: :desc, created_at: :desc) }

  def self.current
    active.first || latest.first
  end

  def activate!
    transaction do
      VeritalkValidator.where.not(id: id).update_all(is_active: false)
      update!(is_active: true)
    end
  end

  def deactivate!
    update!(is_active: false)
  end

  def self.ransackable_attributes(auth_object = nil)
    %w[id name description is_active version created_at updated_at]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[created_by]
  end

  private

  def ensure_single_active
    if is_active? && is_active_changed?
      VeritalkValidator.where.not(id: id).update_all(is_active: false)
    end
  end
end
