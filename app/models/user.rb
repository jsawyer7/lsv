class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :confirmable, :omniauthable, omniauth_providers: [:google_oauth2]

  has_many :claims

  has_many :added_peers, -> { where(status: 'accepted') }, class_name: 'Peer', foreign_key: 'user_id', dependent: :destroy
  has_many :peers, through: :added_peers, source: :peer

  has_many :peerings, -> { where(status: 'accepted') }, class_name: 'Peer', foreign_key: 'peer_id', dependent: :destroy
  has_many :peer_users, through: :peerings, source: :user

  # Peer requests sent by this user
  has_many :sent_peer_requests, -> { where(status: 'pending') }, class_name: 'Peer', foreign_key: 'user_id', dependent: :destroy
  has_many :pending_peers, through: :sent_peer_requests, source: :peer

  # Peer requests received by this user
  has_many :received_peer_requests, -> { where(status: 'pending') }, class_name: 'Peer', foreign_key: 'peer_id', dependent: :destroy
  has_many :peer_requesters, through: :received_peer_requests, source: :user

  # Follow associations
  has_many :follows, dependent: :destroy
  has_many :theories, dependent: :destroy
  has_many :following, through: :follows, source: :followed_user
  has_many :reverse_follows, class_name: 'Follow', foreign_key: 'followed_user', dependent: :destroy
  has_many :followers, through: :reverse_follows, source: :user

  # Define roles
  enum role: {
    user: 0,
    moderator: 1,
    admin: 2
  }

  # Set default role before creation
  before_create :set_default_role

  def active_for_authentication?
    super && (confirmed? || provider.present?)
  end

  def self.from_omniauth(auth)
    # Try to find by provider/uid first
    user = User.find_by(provider: auth.provider, uid: auth.uid)
    
    # If not found by provider/uid, try to find by email
    user ||= User.find_by(email: auth.info.email)
    
    if user
      # Update existing user's OAuth credentials
      user.update(
        provider: auth.provider,
        uid: auth.uid,
        full_name: auth.info.name,
        avatar_url: auth.info.image
      )
    else
      # Create new user if none exists
      user = User.new(
        email: auth.info.email,
        password: Devise.friendly_token[0, 20],
        full_name: auth.info.name,
        avatar_url: auth.info.image,
        provider: auth.provider,
        uid: auth.uid
      )
      user.skip_confirmation!
      user.confirm
      user.save!
    end

    user
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
