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
  has_many :veritalk_token_usages, dependent: :destroy
  has_many :likes, dependent: :destroy
  has_many :comments, dependent: :destroy
  has_many :shares, dependent: :destroy
  has_many :received_shares, class_name: 'Share', foreign_key: 'recipient_id', dependent: :destroy
  has_many :reshared_items, -> { where(recipient_id: nil) }, class_name: 'Share', dependent: :destroy
  has_many :conversations, dependent: :destroy

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
  has_many :notifications, dependent: :destroy
  has_many :led_groups, class_name: 'Group', foreign_key: :leader_id, inverse_of: :leader, dependent: :destroy
  has_many :group_memberships, dependent: :destroy
  has_many :joined_groups, through: :group_memberships, source: :group
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

  # Define religious traditions (using string values)
  enum religious_tradition: {
    jewish: 'jewish',
    christian: 'christian',
    muslim: 'muslim',
    other: 'other',
    not_specified: 'not_specified'
  }

  # Define tradition canons (using string values)
  enum tradition_canon: {
    rabbinic_judaism: 'rabbinic_judaism',
    samaritan: 'samaritan',
    not_sure_jewish: 'not_sure_jewish',
    # Christian canons
    protestant_canon: 'protestant_canon',
    roman_catholic_canon: 'roman_catholic_canon',
    latter_day_saints: 'latter_day_saints',
    syriac_peshitta_canon: 'syriac_peshitta_canon',
    ethiopian_canon: 'ethiopian_canon',
    armenian_apostolic_canon: 'armenian_apostolic_canon',
    coptic_orthodox_canon: 'coptic_orthodox_canon',
    georgian_orthodox_canon: 'georgian_orthodox_canon',
    russian_orthodox_canon: 'russian_orthodox_canon',
    greek_orthodox_canon: 'greek_orthodox_canon',
    anglican_canon: 'anglican_canon',
    lutheran_canon: 'lutheran_canon',
    church_of_the_east_assyr: 'church_of_the_east_assyr',
    eastern_orthodox_canon: 'eastern_orthodox_canon',
    western_orthodox_canon: 'western_orthodox_canon'
  }


  # Set default role before creation
  before_create :set_default_role
  after_commit :enqueue_free_plan_assignment, on: :create

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
    has_entitlement?('ai_evidence_limitation')
  end

  def ai_evidence_limit
    get_entitlement_value('ai_evidence_limitation')
  end

  def ai_evidence_remaining
    return Float::INFINITY if ai_evidence_limit.blank?

    limit = ai_evidence_limit.to_i
    used = ai_evidence_used_this_month
    [limit - used, 0].max
  end

  def can_access_api?
    has_entitlement?('api_access')
  end

  def has_priority_support?
    has_entitlement?('priority_support')
  end

  def can_access_advanced_analytics?
    has_entitlement?('advanced_analytics')
  end

  def can_use_custom_integrations?
    has_entitlement?('custom_integrations')
  end

  def can_use_veritalk?
    return false unless current_active_subscription.present?

    enabled = get_entitlement_value('veritalk_enabled')
    enabled_flag = enabled.to_s == 'true' || enabled.to_s == 'included' || enabled == true

    # If entitlements are unavailable, free/basic/contributor should still have access.
    return veritalk_monthly_token_limit > 0 if enabled.nil?

    enabled_flag && veritalk_monthly_token_limit > 0
  end

  def veritalk_monthly_token_limit
    entitlement_value = get_entitlement_value('veritalk_monthly_tokens')
    parsed = entitlement_value.to_i
    return parsed if parsed.positive?

    fallback_veritalk_monthly_token_limit
  end

  def veritalk_tokens_used_this_month
    veritalk_token_usages.this_month.sum(:total_tokens)
  end

  def veritalk_tokens_remaining
    limit = veritalk_monthly_token_limit
    return 0 if limit <= 0

    [limit - veritalk_tokens_used_this_month, 0].max
  end

  def can_create_claims?
    has_entitlement?('can_create_claims')
  end

  def can_submit_challenges?
    has_entitlement?('can_submit_challenges')
  end

  def can_create_theories?
    has_entitlement?('can_create_theories')
  end

  def record_veritalk_usage!(conversation:, input_tokens:, output_tokens:)
    veritalk_token_usages.create!(
      conversation: conversation,
      input_tokens: input_tokens.to_i,
      output_tokens: output_tokens.to_i,
      used_at: Time.current
    )
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

  def enqueue_free_plan_assignment_if_missing!
    return if chargebee_subscriptions.where(status: %w[active in_trial non_renewing]).exists?

    throttle_key = "free_plan_assignment:#{id}"
    return if Rails.cache.exist?(throttle_key)

    Rails.cache.write(throttle_key, true, expires_in: 30.minutes)
    AssignFreePlanJob.perform_later(id)
  rescue => e
    Rails.logger.error("Failed to enqueue missing free plan assignment for user #{id}: #{e.message}")
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
    current_subscription = current_active_subscription

    return [] unless current_subscription&.chargebee_id

    begin
      result = ChargeBee::SubscriptionEntitlement.subscription_entitlements_for_subscription(
        current_subscription.chargebee_id
      )

      entitlements = result.map do |item|
        {
          feature_id: item.subscription_entitlement.feature_id,
          feature_name: item.subscription_entitlement.feature_name,
          value: item.subscription_entitlement.value
        }
      end
      return merge_tier_defaults(current_subscription, entitlements) if entitlements.present?

      fallback_entitlements_for_subscription(current_subscription)
    rescue => e
      Rails.logger.error "Error fetching entitlements: #{e.message}"
      fallback_entitlements_for_subscription(current_subscription)
    end
  end

  def merge_tier_defaults(subscription, entitlements)
    defaults = fallback_entitlements_for_subscription(subscription)
    merged = defaults.index_by { |e| e[:feature_id] }
    entitlements.each { |ent| merged[ent[:feature_id]] = ent }
    merged.values
  end

  def fallback_entitlements_for_subscription(subscription)
    plan = subscription&.chargebee_plan
    tier = plan_tier(plan)
    tier ||= :free if subscription.present?

    default_entitlements = [
      { feature_id: "veritalk_enabled", feature_name: "VeriTalk Enabled", value: "true" },
      { feature_id: "veritalk_monthly_tokens", feature_name: "VeriTalk Monthly Tokens", value: fallback_tokens_for_tier(tier) },
      { feature_id: "can_like_comment_save_favorites", feature_name: "Community Features", value: "true" }
    ]

    if tier == :contributor
      default_entitlements.concat(
        [
          { feature_id: "can_create_claims", feature_name: "Can Create Claims", value: "true" },
          { feature_id: "can_submit_challenges", feature_name: "Can Submit Challenges", value: "true" },
          { feature_id: "can_create_theories", feature_name: "Can Create Theories", value: "true" }
        ]
      )
    end

    metadata_entitlements = Array(plan&.metadata&.dig("entitlements")).map do |item|
      {
        feature_id: item["feature_id"].to_s,
        feature_name: item["feature_name"],
        value: normalized_fallback_entitlement_value(item["feature_id"], item["value"], tier)
      }
    end

    if metadata_entitlements.present?
      merged = default_entitlements.index_by { |e| e[:feature_id] }
      metadata_entitlements.each { |ent| merged[ent[:feature_id]] = ent }
      return merged.values
    end

    default_entitlements
  end

  def plan_tier(plan)
    return nil unless plan

    name = plan.name.to_s.downcase
    item_price_id = plan.chargebee_item_price_id.to_s.downcase

    return :contributor if name.include?("contributor") || item_price_id.include?("contributor") ||
                           name.include?("premium") || item_price_id.include?("premium")
    return :basic if name.include?("basic") || item_price_id.include?("basic") ||
                     name.include?("plus") || item_price_id.include?("plus") ||
                     name.include?("pro") || item_price_id.include?("pro")
    return :free if name.include?("free") || plan.price.to_f.zero?

    nil
  end

  def fallback_veritalk_monthly_token_limit
    subscription = current_active_subscription
    tier = plan_tier(subscription&.chargebee_plan)
    return 0 if tier.nil?

    fallback_tokens_for_tier(tier).to_i
  end

  def fallback_tokens_for_tier(tier)
    case tier
    when :contributor
      ENV.fetch("VERITALK_CONTRIBUTOR_MONTHLY_TOKENS", "200000")
    when :basic
      ENV.fetch("VERITALK_BASIC_MONTHLY_TOKENS", "80000")
    else
      ENV.fetch("VERITALK_FREE_MONTHLY_TOKENS", "20000")
    end
  end

  def normalized_fallback_entitlement_value(feature_id, value, tier)
    return fallback_tokens_for_tier(tier) if feature_id.to_s == "veritalk_monthly_tokens" && value.to_i <= 0
    return "true" if value.to_s == "included"

    value
  end

  def current_active_subscription
    chargebee_subscriptions
      .where(status: %w[active in_trial non_renewing])
      .order(updated_at: :desc, created_at: :desc)
      .first
  end

  def enqueue_free_plan_assignment
    AssignFreePlanJob.perform_later(id)
  rescue => e
    Rails.logger.error("Failed to enqueue free plan assignment for user #{id}: #{e.message}")
  end
end
