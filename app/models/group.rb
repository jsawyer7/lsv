class Group < ApplicationRecord
  belongs_to :leader, class_name: 'User'
  has_many :group_memberships, dependent: :destroy
  has_many :members, through: :group_memberships, source: :user

  validates :name, presence: true, length: { maximum: 120 }

  def member?(user)
    return false unless user
    user.id == leader_id || group_memberships.exists?(user_id: user.id)
  end
end
