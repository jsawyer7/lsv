class Claim < ApplicationRecord
  belongs_to :user

  validates :content, presence: true
  validates :evidence, presence: true

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
