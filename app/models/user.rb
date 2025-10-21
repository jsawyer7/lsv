class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :confirmable, :omniauthable, omniauth_providers: [:google_oauth2, :twitter, :facebook]

  has_many :claims
  has_many :chargebee_subscriptions, dependent: :destroy
  has_many :chargebee_billings, dependent: :destroy
  has_many :ai_evidence_usages, dependent: :destroy

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

  # Helper method to get avatar URL that works in both development and production
  def avatar_url
    if avatar.attached?
      Rails.application.routes.url_helpers.rails_blob_url(avatar, only_path: true)
    elsif self[:avatar_url].present?
      self[:avatar_url]
    else
      nil
    end
  end

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
    %w[claims]
  end

  # Entitlement-based access control methods
  def has_entitlement?(feature_id)
    current_entitlements.any? { |entitlement| entitlement[:feature_id] == feature_id }
  end

  def get_entitlement_value(feature_id)
    entitlement = current_entitlements.find { |entitlement| entitlement[:feature_id] == feature_id }
    entitlement&.dig(:value)
  end

  def can_generate_ai_evidence?
    has_entitlement?('ai_evidence_limitation')
  end

  def ai_evidence_limit
    get_entitlement_value('ai_evidence_limitation')
  end

  def ai_evidence_remaining
    return 0 unless can_generate_ai_evidence?

    limit = ai_evidence_limit
    return Float::INFINITY if limit.to_s.downcase == 'unlimited' || limit.to_i >= 999999

    used = ai_evidence_used_this_month
    [limit.to_i - used, 0].max
  end

  def can_access_api?
    has_entitlement?('api_access') && get_entitlement_value('api_access') == 'true'
  end

  def has_priority_support?
    has_entitlement?('priority_support') && get_entitlement_value('priority_support') == 'true'
  end

  def can_access_advanced_analytics?
    has_entitlement?('advanced_analytics') && get_entitlement_value('advanced_analytics') == 'true'
  end

  def can_use_custom_integrations?
    has_entitlement?('custom_integrations') && get_entitlement_value('custom_integrations') == 'true'
  end

  def ai_evidence_used_this_month
    ai_evidence_usages.this_month.sum(:usage_count)
  end

  def record_ai_evidence_usage(count = 1)
    ai_evidence_usages.create!(
      used_at: Time.current,
      feature_type: 'ai_evidence',
      usage_count: count
    )
  end

  def first_name
    full_name.to_s.split.first || "User"
  end

  def last_name
    full_name.to_s.split[1..].to_a.join(" ") || ""
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

  def current_entitlements
    @current_entitlements ||= fetch_current_entitlements
  end

  def fetch_current_entitlements
    current_subscription = chargebee_subscriptions
      .where(status: %w[active in_trial non_renewing])
      .order(updated_at: :desc, created_at: :desc)
      .first

    return [] unless current_subscription&.chargebee_id

    begin
      result = ChargeBee::SubscriptionEntitlement.subscription_entitlements_for_subscription(
        current_subscription.chargebee_id
      )

      result.map do |item|
        {
          feature_id: item.subscription_entitlement.feature_id,
          feature_name: item.subscription_entitlement.feature_name,
          value: item.subscription_entitlement.value
        }
      end
    rescue => e
      Rails.logger.error "Error fetching entitlements: #{e.message}"
      []
    end
  end
end
