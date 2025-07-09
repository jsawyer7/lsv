class Claim < ApplicationRecord
  belongs_to :user
  has_many :challenges, dependent: :destroy
  has_many :reasonings, as: :reasonable, dependent: :destroy
  has_many :evidences, dependent: :destroy

  validates :content, presence: true

  enum state: {
    draft: 'draft',
    ai_validated: 'ai_validated',
    verified: 'verified'
  }, _default: 'draft'

  scope :drafts, -> { where(state: 'draft') }
  scope :ai_validated, -> { where(state: 'ai_validated') }
  scope :verified, -> { where(state: 'verified') }

  def reasoning_for(source)
    reasonings.find_by(source: source)&.response
  end

  # Define ransackable attributes
  def self.ransackable_attributes(auth_object = nil)
    %w[
      id
      content
      created_at
      updated_at
      user_id
    ]
  end

  # Define ransackable associations
  def self.ransackable_associations(auth_object = nil)
    %w[user reasonings evidences]
  end
end
