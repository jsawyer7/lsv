class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :confirmable, :omniauthable, omniauth_providers: [:google_oauth2]

  has_many :claims

  # Define roles
  enum role: {
    user: 0,
    moderator: 1,
    admin: 2
  }

  # Set default role before creation
  before_create :set_default_role

  def active_for_authentication?
    super && confirmed?
  end

  def self.from_omniauth(auth)
    where(provider: auth.provider, uid: auth.uid).first_or_create do |user|
      user.email = auth.info.email
      user.password = Devise.friendly_token[0, 20]
      user.full_name = auth.info.name
      user.avatar_url = auth.info.image
    end
  end

  # Define ransackable attributes
  def self.ransackable_attributes(auth_object = nil)
    %w[
      id
      email
      role
      full_name
      created_at
      updated_at
      confirmed_at
      provider
      uid
    ]
  end

  # Define ransackable associations
  def self.ransackable_associations(auth_object = nil)
    %w[claims]
  end

  private

  def set_default_role
    self.role ||= :user
  end
end
