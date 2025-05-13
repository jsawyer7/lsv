class Claim < ApplicationRecord
  belongs_to :user
  has_many :challenges, dependent: :destroy

  validates :content, presence: true
  validates :evidence, presence: true
  validates :status, inclusion: { in: %w[pending processing completed failed] }

  scope :pending, -> { where(status: 'pending') }
  scope :completed, -> { where(status: 'completed') }
  scope :failed, -> { where(status: 'failed') }
  scope :processing, -> { where(status: 'processing') }

  # Define ransackable attributes
  def self.ransackable_attributes(auth_object = nil)
    %w[
      id
      content
      evidence
      created_at
      updated_at
      user_id
    ]
  end

  # Define ransackable associations
  def self.ransackable_associations(auth_object = nil)
    %w[user]
  end
end
