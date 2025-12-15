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
  has_many :likes, dependent: :destroy
  has_many :comments, dependent: :destroy
  has_many :shares, dependent: :destroy
  has_many :received_shares, class_name: 'Share', foreign_key: 'recipient_id', dependent: :destroy
  has_many :reshared_items, -> { where(recipient_id: nil) }, class_name: 'Share', dependent: :destroy

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

  # Define naming preferences
  enum naming_preference: {
    hebrew_aramaic: 0,
    greco_latin_english: 1,
    arabic: 2
  }


  # Set default role before creation
  before_create :set_default_role

  has_one_attached :avatar
  has_one_attached :background_image
  validates :about, length: { maximum: 1000 }
  # Only validate naming preference for existing users who are trying to perform actions that require it
  validates :naming_preference, presence: true, if: :requires_naming_preference?
  validate :avatar_type_and_size
  validate :background_image_type_and_size

  # Helper method to get avatar URL that works in both development and production
  def avatar_url
    if avatar.attached?
      # Use compressed version for better performance
      compressed_avatar = avatar.variant(resize_to_limit: [300, 300], quality: 85)
      Rails.application.routes.url_helpers.rails_blob_url(compressed_avatar, only_path: true)
    elsif self[:avatar_url].present?
      self[:avatar_url]
    else
      nil
    end
  end

  # Helper method to get background image URL
  def background_image_url
    if background_image.attached?
      # Use compressed version for better performance
      # Banner is 350px high, using 3.5:1 aspect ratio (1400x400)
      compressed_bg = background_image.variant(resize_to_limit: [1400, 400], quality: 80)
      Rails.application.routes.url_helpers.rails_blob_url(compressed_bg, only_path: true)
    else
      nil
    end
  end

  # Helper methods to get original full-size images when needed
  def avatar_url_original
    if avatar.attached?
      Rails.application.routes.url_helpers.rails_blob_url(avatar, only_path: true)
    elsif self[:avatar_url].present?
      self[:avatar_url]
    else
      nil
    end
  end

  def background_image_url_original
    if background_image.attached?
      Rails.application.routes.url_helpers.rails_blob_url(background_image, only_path: true)
    else
      nil
    end
  end

  def active_for_authentication?
    super && (confirmed? || provider.present?)
  end

  # Check if user has completed onboarding (has set naming preference)
  def onboarding_complete?
    naming_preference.present?
  end

  # Map naming preference to tradition for name translation
  def tradition_for_naming_preference
    case naming_preference
    when 'hebrew_aramaic'
      'jewish'
    when 'greco_latin_english'
      'christian'
    when 'arabic'
      'muslim'
    else
      'actual' # default fallback
    end
  end

  # Check if the current action requires naming preference validation
  def requires_naming_preference?
    # Don't validate during signup
    return false if new_record?

    # Don't validate if user is just updating basic profile info without changing naming preference
    return false if persisted? && !naming_preference_changed? && !naming_preference_was.present?

    # For now, be permissive - only validate when explicitly needed
    # This can be enhanced later to check specific actions that require naming preference
    false
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
      update_params = {
        provider: auth.provider,
        uid: auth.uid,
        full_name: user.full_name.presence || auth.info.name,
        avatar_url: auth.info.image
      }

      # Store OAuth tokens for API access
      if auth.credentials.present?
        update_params[:oauth_token] = auth.credentials.token if auth.credentials.token.present?
        update_params[:oauth_token_secret] = auth.credentials.secret if auth.credentials.secret.present?
        update_params[:oauth_refresh_token] = auth.credentials.refresh_token if auth.credentials.refresh_token.present?
        update_params[:oauth_expires_at] = Time.at(auth.credentials.expires_at) if auth.credentials.expires_at.present?
      end

      user.update(update_params)
    else
      # Create new user if none exists
      # For X OAuth, email might not be available, so we'll use a placeholder
      email = auth.info.email.presence || "#{auth.info.screen_name}@twitter.com"

      user_params = {
        email: email,
        password: Devise.friendly_token[0, 20],
        full_name: auth.info.name,
        avatar_url: auth.info.image,
        provider: auth.provider,
        uid: auth.uid
      }

      # Store OAuth tokens for API access
      if auth.credentials.present?
        user_params[:oauth_token] = auth.credentials.token if auth.credentials.token.present?
        user_params[:oauth_token_secret] = auth.credentials.secret if auth.credentials.secret.present?
        user_params[:oauth_refresh_token] = auth.credentials.refresh_token if auth.credentials.refresh_token.present?
        user_params[:oauth_expires_at] = Time.at(auth.credentials.expires_at) if auth.credentials.expires_at.present?
      end

      user = User.new(user_params)
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
      naming_preference
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
    # Allow AI evidence generation for all users (free service)
    true
  end

  def ai_evidence_limit
    get_entitlement_value('ai_evidence_limitation')
  end

  def ai_evidence_remaining
    # Return unlimited for all users (free service)
    Float::INFINITY
  end

  def can_access_api?
    # Allow API access for all users (free service)
    true
  end

  def has_priority_support?
    # Allow priority support for all users (free service)
    true
  end

  def can_access_advanced_analytics?
    # Allow advanced analytics for all users (free service)
    true
  end

  def can_use_custom_integrations?
    # Allow custom integrations for all users (free service)
    true
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
    # Size limit removed - images will be automatically compressed
  end

  def background_image_type_and_size
    return unless background_image.attached?
    if !background_image.content_type.in?(%w[image/png image/jpg image/jpeg])
      errors.add(:background_image, 'must be a PNG or JPG')
    end
    # Size limit removed - images will be automatically compressed
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
