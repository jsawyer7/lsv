class AssignFreePlanService
  ACTIVE_SUBSCRIPTION_STATUSES = %w[active in_trial non_renewing].freeze

  def initialize(user:)
    @user = user
  end

  def call
    if user_has_active_local_subscription?
      Rails.logger.info("AssignFreePlanService: user #{user.id} already has active local subscription")
      return
    end

    customer_id = find_or_create_customer_id
    return if customer_id.blank?

    item_price_id = resolve_free_item_price_id
    if item_price_id.blank?
      Rails.logger.warn("AssignFreePlanService: no usable free item_price_id found")
      return
    end

    existing_subscription = find_active_subscription_for_customer(customer_id)
    if existing_subscription.present?
      Rails.logger.info("AssignFreePlanService: found existing active Chargebee subscription #{existing_subscription.id} for user #{user.id}")
      sub = subscription_with_line_items(existing_subscription)
      from_subscription = item_price_id_from_subscription(sub)
      sync_id = from_subscription.presence || item_price_id
      if from_subscription.present? && from_subscription != item_price_id
        Rails.logger.info("AssignFreePlanService: syncing from subscription line items (#{sync_id}), not configured default (#{item_price_id})")
      end
      sync_plan_and_subscription(sub, sync_id)
      return
    end

    result = ChargeBee::Subscription.create_with_items(
      customer_id,
      {
        subscription_items: [{ item_price_id: item_price_id }]
      }
    )

    Rails.logger.info("AssignFreePlanService: created free subscription #{result.subscription.id} for user #{user.id}")
    sync_plan_and_subscription(result.subscription, item_price_id)
  rescue => e
    Rails.logger.error("AssignFreePlanService failed for user #{user.id}: #{e.message}")
    raise
  end

  private

  attr_reader :user

  def configured_free_item_price_id
    ENV["CHARGEBEE_FREE_ITEM_PRICE_ID"].presence || "free-USD-Monthly"
  end

  def user_has_active_local_subscription?
    user.chargebee_subscriptions.where(status: ACTIVE_SUBSCRIPTION_STATUSES).exists?
  end

  def find_or_create_customer_id
    existing_customer = ChargeBee::Customer.list({ "email[is]" => user.email }).first
    if existing_customer&.customer
      Rails.logger.info("AssignFreePlanService: found Chargebee customer #{existing_customer.customer.id} for user #{user.id}")
      return existing_customer.customer.id
    end

    result = ChargeBee::Customer.create(
      email: user.email,
      first_name: user.full_name.presence || user.first_name
    )

    Rails.logger.info("AssignFreePlanService: created Chargebee customer #{result.customer.id} for user #{user.id}")
    result.customer.id
  end

  def find_active_subscription_for_customer(customer_id)
    # chargebee-ruby v2.60.0 is picky about nested/filter formats.
    # List by customer and filter statuses locally to avoid format errors.
    subscriptions = ChargeBee::Subscription.list(customer_id: customer_id)

    match = subscriptions.find do |response|
      sub = response.subscription
      sub&.customer_id.to_s == customer_id.to_s && ACTIVE_SUBSCRIPTION_STATUSES.include?(sub.status.to_s)
    end

    match&.subscription
  rescue => e
    Rails.logger.error("AssignFreePlanService: failed to list subscriptions for customer #{customer_id}: #{e.message}")
    nil
  end

  # List responses may omit embedded line items; retrieve full subscription when needed.
  def subscription_with_line_items(subscription)
    return subscription if subscription.subscription_items.present?

    ChargeBee::Subscription.retrieve(subscription.id).subscription
  rescue StandardError => e
    Rails.logger.warn("AssignFreePlanService: could not retrieve subscription #{subscription.id}: #{e.message}")
    subscription
  end

  def item_price_id_from_subscription(subscription)
    items = subscription.subscription_items
    return nil if items.blank?

    plan_line = items.find { |i| i.respond_to?(:item_type) && i.item_type.to_s == "plan" }
    line = plan_line || items.first
    line&.item_price_id.presence
  end

  def find_item_price(item_price_id)
    ChargeBee::ItemPrice.retrieve(item_price_id).item_price
  rescue => e
    Rails.logger.error("AssignFreePlanService: failed to retrieve item price #{item_price_id}: #{e.message}")
    nil
  end

  def resolve_free_item_price_id
    configured = configured_free_item_price_id
    return configured if find_item_price(configured).present?

    Rails.logger.warn("AssignFreePlanService: configured free item_price_id '#{configured}' is invalid, discovering fallback")
    discover_free_item_price_id
  end

  def discover_free_item_price_id
    # Prefer active plans with "free" in either item_price_id, name, or item_id.
    candidates = ChargeBee::ItemPrice.list(status: "active", limit: 100)
    free = candidates.map(&:item_price).find do |ip|
      [ip.id, ip.name, ip.item_id].any? { |v| v.to_s.downcase.include?("free") }
    end

    return free.id if free.present?

    Rails.logger.error("AssignFreePlanService: unable to auto-discover a free active item_price_id")
    nil
  rescue => e
    Rails.logger.error("AssignFreePlanService: failed to discover free item_price_id: #{e.message}")
    nil
  end

  def sync_plan_and_subscription(subscription, item_price_id)
    return if subscription.blank?

    item_price = find_item_price(item_price_id)
    return if item_price.blank?

    plan = ChargebeePlan.find_or_initialize_by(chargebee_item_price_id: item_price.id)
    plan.chargebee_id = item_price.item_id
    plan.name = item_price.name
    plan.price = item_price.price.to_f / 100
    plan.billing_cycle = [item_price.period, item_price.period_unit].compact.join(" ")
    plan.status = item_price.status
    plan.save!

    sub_record = user.chargebee_subscriptions.find_or_initialize_by(chargebee_id: subscription.id)
    sub_record.update!(
      chargebee_plan: plan,
      status: subscription.status,
      current_term_start: safe_unix_to_time(subscription.current_term_start),
      current_term_end: safe_unix_to_time(subscription.current_term_end),
      trial_start: safe_unix_to_time(subscription.trial_start),
      trial_end: safe_unix_to_time(subscription.trial_end),
      metadata: subscription.respond_to?(:attributes) ? subscription.attributes : {}
    )
    Rails.logger.info("AssignFreePlanService: synced local subscription #{sub_record.chargebee_id} with status #{sub_record.status} for user #{user.id}")
  end

  def safe_unix_to_time(timestamp)
    return nil if timestamp.blank?

    Time.at(timestamp)
  end
end
