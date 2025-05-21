class Challenge < ApplicationRecord
  belongs_to :claim
  belongs_to :user
  has_many :reasonings, as: :reasonable, dependent: :destroy

  validates :text, presence: true
  validates :status, inclusion: { in: %w[pending processing completed failed] }

  scope :pending, -> { where(status: 'pending') }
  scope :completed, -> { where(status: 'completed') }
  scope :failed, -> { where(status: 'failed') }
  scope :processing, -> { where(status: 'processing') }
end
