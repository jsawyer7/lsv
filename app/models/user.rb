class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :confirmable, :omniauthable, omniauth_providers: [:google_oauth2, :twitter, :facebook]

  has_many :claims
  has_many :subscriptions, dependent: :destroy
  has_one :customer, dependent: :destroy

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

  has_one_attached :avatar
  validates :about, length: { maximum: 1000 }
  validate :avatar_type_and_size

  def active_for_authentication?
    super && (confirmed? || provider.present?)
  end

  def self.from_omniauth(auth)
    # Try to find by provider/uid first
    user = User.find_by(provider: auth.provider, uid: auth.uid)
    
    # If not found by provider/uid, try to find by email (if available)
    if auth.info.email.present?
      user ||= User.find_by(email: auth.info.email)
    end
    
    if user
      # Update existing user's OAuth credentials
      user.update(
        provider: auth.provider,
        uid: auth.uid,
        full_name: user.full_name.presence || auth.info.name,
        avatar_url: auth.info.image
      )
    else
      # Create new user if none exists
      # For X OAuth, email might not be available, so we'll use a placeholder
      email = auth.info.email.presence || "#{auth.info.screen_name}@twitter.com"
      
      user = User.new(
        email: email,
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
    %w[claims subscriptions customer]
  end

  # Subscription methods
  def current_subscription
    subscriptions.active.first
  end

  def current_plan
    current_subscription&.plan
  end

  def has_active_subscription?
    subscriptions.active.exists?
  end

  def subscription_status
    current_subscription&.status || 'none'
  end

  def can_access_feature?(feature_name)
    return true if admin? || moderator?
    current_plan&.feature_enabled?(feature_name) || false
  end

  def subscription_expires_at
    current_subscription&.current_term_end
  end

  def days_until_subscription_expires
    return nil unless subscription_expires_at
    (subscription_expires_at - Time.current).to_i / 1.day
  end

  private

  def set_default_role
    self.role ||= :user
  end

  def avatar_type_and_size
    return unless avatar.attached?
    if !avatar.content_type.in?(%w[image/png image/jpg image/jpeg])
      errors.add(:avatar, 'must be a PNG or JPG')
    end
    if avatar.byte_size > 800.kilobytes
      errors.add(:avatar, 'size must be less than 800KB')
    end
  end
end
