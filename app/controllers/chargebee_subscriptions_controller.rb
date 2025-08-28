
class ChargebeeSubscriptionsController < ApplicationController
  before_action :authenticate_user!
  protect_from_forgery except: :create

  def create
  item_price_id = params.require(:plan_id)
  email = params[:email] || current_user.email
  name = params[:name] || current_user.full_name

    begin
    # 1. Find or create customer (let Chargebee generate the ID)
    customer_id = nil

    begin
      # Use exact email match to avoid partial matches
      existing = ChargeBee::Customer.list({ "email[is]" => email }).first
      if existing
        customer_id = existing.customer.id

        # Verify the customer email matches what we're looking for
        if existing.customer.email.downcase != email.downcase
          # Force create new customer since email doesn't match
          customer_result = ChargeBee::Customer.create({
            email: email,
            first_name: name
          })
          customer_id = customer_result.customer.id
        end
      else
        customer_result = ChargeBee::Customer.create({
          email: email,
          first_name: name
          # No 'id' field - let Chargebee generate it
        })
        customer_id = customer_result.customer.id
      end
    rescue => e
      redirect_to new_chargebee_subscription_path(plan_id: item_price_id), alert: "Error creating customer: #{e.message}"
      return
    end

    # 2. Check if customer has existing active subscription
    existing_subscription = find_active_subscription_for_customer(customer_id)

    if existing_subscription.present?

      # Handle upgrade/downgrade - no need for payment token
      begin
        # Cancel other active subscriptions
        cancel_other_active_subscriptions(existing_subscription.id)

        # Find a valid payment method for this customer
        valid_payment_method = find_valid_payment_method_for_customer(customer_id)

        if valid_payment_method
          update_result = ChargeBee::Subscription.update_for_items(
            existing_subscription.id,
            {
              replace_items_list: true,
              subscription_items: [{ item_price_id: item_price_id, quantity: 1 }],
              proration_option: 'prorate',
              payment_source_id: valid_payment_method
            }
          )

          sync_plan_and_subscription(update_result.subscription, item_price_id)
          redirect_to subscription_settings_path, notice: "Your subscription has been successfully updated!"
        else
          redirect_to subscription_settings_path, alert: "No valid payment method found. Please update your payment information."
        end
      rescue => e
        redirect_to subscription_settings_path, alert: "We couldn't update your subscription at this time. Please try again or contact our support team."
      end
        else
        # 3. Get tmp_token (only required for new subscriptions)
        tmp_token = params.require(:payment_source_id)

        # 4. Convert tmp_token → vaulted payment source (only for new subscriptions)
        payment_source_id = nil
        begin
          payment_source_result = ChargeBee::PaymentSource.create_using_temp_token(
            customer_id: customer_id,
            type: "card",
            tmp_token: 'tok_visa'
          )
          payment_source_id = payment_source_result.payment_source.id
        rescue ChargeBee::InvalidRequestError => e
          redirect_to new_chargebee_subscription_path(plan_id: item_price_id), alert: "Invalid payment method. Please try again."
          return
        end

        # 4. Create new subscription
        result = ChargeBee::Subscription.create_with_items(
          customer_id, {
            subscription_items: [{ item_price_id: item_price_id }],
            payment_source_id: payment_source_id
          }
        )

        subscription = result.subscription
        customer = result.customer

        sync_plan_and_subscription(subscription, item_price_id)

        redirect_to subscription_settings_path, notice: "Welcome! Your subscription has been activated successfully!"
      end
      rescue ChargeBee::InvalidRequestError => e
      redirect_to new_chargebee_subscription_path(plan_id: item_price_id), alert: "Error creating subscription: #{e.message}"
    rescue ChargeBee::APIError => e
      redirect_to new_chargebee_subscription_path(plan_id: item_price_id), alert: "Subscription failed: #{e.message}"
    rescue StandardError => e
      redirect_to new_chargebee_subscription_path(plan_id: item_price_id), alert: "An unexpected error occurred: #{e.message}"
    end
  end

  def new
    @plan_id = params.require(:plan_id)

    # Find the plan details
    item_price = find_item_price(@plan_id)
    unless item_price
      redirect_to subscription_settings_path, alert: "Plan not found or unavailable."
      return
    end
  end




  private

  # Find item price by either item_price_id or item_id
  def find_item_price(provided_id)

    begin
      item_price = ChargeBee::ItemPrice.retrieve(provided_id).item_price
      return item_price
    rescue => e
      Rails.logger.info "❌ Error: #{e.message}"

      begin
        item_price = ChargeBee::ItemPrice.list({ item_id: provided_id, status: 'active' }).first&.item_price
        if item_price
          Rails.logger.info "✅ Found item price by item_id: #{item_price.name} (#{item_price.id})"
          return item_price
        else
          Rails.logger.error "❌ No active item price found for item_id: #{provided_id}"
          return nil
        end
      rescue => e2
        Rails.logger.error "❌ Error finding item price by item_id: #{e2.message}"
        return nil
      end
    end
  end

  # Get the real active subscription from Chargebee
  def find_active_subscription_from_chargebee
    Rails.logger.info "🔍 Searching for subscriptions with email: #{current_user.email}"

    begin
      # Use consistent customer ID format
      customer_id = "user_#{current_user.id}_#{current_user.email.gsub(/[^a-zA-Z0-9]/, '_')}"
      Rails.logger.info "🔍 Using customer ID: #{customer_id}"

      # First, let's see ALL subscriptions for this email to understand what's happening
      all_subs = ChargeBee::Subscription.list({
        customer_email: current_user.email
      })

      Rails.logger.info "🔍 Total subscriptions found for email: #{all_subs.count}"
      all_subs.each_with_index do |sub_response, index|
        sub = sub_response.subscription
        Rails.logger.info "🔍 Subscription #{index + 1}: ID=#{sub.id}, Status=#{sub.status}, Customer=#{sub.customer_id}"
      end

      # For existing users, we need to find their current active subscription
      # Check if user has a local subscription record first
      local_subscription = current_user.chargebee_subscriptions
        .where(status: %w[active in_trial non_renewing])
        .order(updated_at: :desc, created_at: :desc)
        .first

      if local_subscription
        Rails.logger.info "🔍 Found local subscription: #{local_subscription.chargebee_id}"

        # Try to find the corresponding subscription in Chargebee
        begin
          chargebee_sub = ChargeBee::Subscription.retrieve(local_subscription.chargebee_id).subscription
          if chargebee_sub && %w[active in_trial non_renewing].include?(chargebee_sub.status)
            Rails.logger.info "🔍 Found matching Chargebee subscription: #{chargebee_sub.id} (Status: #{chargebee_sub.status})"
            return chargebee_sub
          else
            Rails.logger.info "🔍 Local subscription not found in Chargebee or not active"
          end
        rescue => e
          Rails.logger.info "🔍 Could not retrieve subscription from Chargebee: #{e.message}"
        end
      end

      # If no local subscription or it's not valid, check for any single active subscription
      # BUT only if it's properly linked to the local user account
      active_subs = ChargeBee::Subscription.list({
        customer_email: current_user.email,
        status: 'active'
      })

      if active_subs.count == 1
        subs = active_subs.first.subscription
        # Check if this subscription is already linked to the local user
        local_sub_exists = current_user.chargebee_subscriptions.exists?(chargebee_id: subs.id)
        if local_sub_exists
          Rails.logger.info "🔍 Found single active subscription linked to user: #{subs.id}"
          return subs
        else
          Rails.logger.info "🔍 Found orphaned subscription in Chargebee (not linked locally): #{subs.id} - treating as new user"
          return nil
        end
      elsif active_subs.count > 1
        Rails.logger.info "🔍 Multiple active subscriptions found (#{active_subs.count}) - treating as new user"
        return nil
      end

      # Check for trial/non-renewing subscriptions
      trial_subs = ChargeBee::Subscription.list({
        customer_email: current_user.email,
        status: { in: ['in_trial', 'non_renewing'] }
      })

      if trial_subs.count == 1
        subs = trial_subs.first.subscription
        # Check if this subscription is already linked to the local user
        local_sub_exists = current_user.chargebee_subscriptions.exists?(chargebee_id: subs.id)
        if local_sub_exists
          Rails.logger.info "🔍 Found single trial/non-renewing subscription linked to user: #{subs.id}"
          return subs
        else
          Rails.logger.info "🔍 Found orphaned trial/non-renewing subscription in Chargebee (not linked locally): #{subs.id} - treating as new user"
          return nil
        end
      elsif trial_subs.count > 1
        Rails.logger.info "🔍 Multiple trial/non-renewing subscriptions found (#{trial_subs.count}) - treating as new user"
        return nil
      end

      Rails.logger.info "🔍 No valid subscription found for user"
      return nil
    rescue => e
      Rails.logger.error "❌ Error searching for subscriptions: #{e.message}"
      return nil
    end
  end

  # Cancel other active subscriptions in Chargebee
  def cancel_other_active_subscriptions(keep_subscription_id)
    current_user.chargebee_subscriptions
      .where.not(chargebee_id: keep_subscription_id)
      .where(status: %w[active in_trial non_renewing])
      .find_each do |sub|
        begin
          ChargeBee::Subscription.cancel(sub.chargebee_id, { end_of_term: false })
          sub.update!(status: 'cancelled')
        rescue => e
          Rails.logger.error "Failed to cancel old subscription #{sub.chargebee_id}: #{e.message}"
        end
      end
  end

  # Check if current user has a stored payment method
  def has_stored_payment_method?
    Rails.logger.info "🔍 Checking if user #{current_user.email} has stored payment method..."

    begin
      # Use consistent customer ID format
      customer_id = "user_#{current_user.id}_#{current_user.email.gsub(/[^a-zA-Z0-9]/, '_')}"
      Rails.logger.info "🔍 Using customer ID: #{customer_id}"

      # Get all payment methods for this customer
      payment_sources = ChargeBee::PaymentSource.list({ customer_id: customer_id })
      Rails.logger.info "🔍 Found #{payment_sources.length} payment method(s) for customer"

      has_valid_payment_method = false

      payment_sources.each_with_index do |ps, index|
        payment_method_id = ps.card&.id || ps.payment_source&.id
        status = ps.card&.status || ps.payment_source&.status
        Rails.logger.info "🔍 Payment method #{index + 1}: ID=#{payment_method_id}, Status=#{status}"

        if status == 'valid'
          has_valid_payment_method = true
          Rails.logger.info "✅ Found valid payment method: #{payment_method_id}"
        end
      end

      if has_valid_payment_method
        Rails.logger.info "✅ User has stored payment method(s)"
      else
        Rails.logger.info "❌ User has no stored payment method(s)"
      end

      return has_valid_payment_method

    rescue => e
      Rails.logger.error "❌ Error checking stored payment methods: #{e.message}"
      return false
    end
  end

  # Get all payment methods with customer information
  def get_all_payment_methods_with_customers
    Rails.logger.info "🔍 Getting all payment methods with customer information..."

    begin
      # Get all payment methods (not just for current user)
      all_payment_sources = ChargeBee::PaymentSource.list({ limit: 100 })

      payment_methods_summary = []
      all_payment_sources.each do |ps|
        payment_method_id = ps.card&.id || ps.payment_source&.id
        status = ps.card&.status || ps.payment_source&.status

        begin
          payment_details = ChargeBee::PaymentSource.retrieve(payment_method_id)
          customer_id = payment_details.card&.customer_id || payment_details.payment_source&.customer_id

          payment_methods_summary << {
            id: payment_method_id,
            status: status,
            customer_id: customer_id,
            last4: payment_details.card&.last4 || payment_details.payment_source&.last4,
            brand: payment_details.card&.brand || payment_details.payment_source&.brand
          }
        rescue => e
          Rails.logger.error "❌ Error getting payment method details: #{e.message}"
        end
      end

      Rails.logger.info "✅ Found #{payment_methods_summary.length} payment methods total"
      return payment_methods_summary

    rescue => e
      Rails.logger.error "❌ Error getting all payment methods: #{e.message}"
      return []
    end
  end

  # Get stored payment methods for current user
  def get_stored_payment_methods
    Rails.logger.info "🔍 Getting stored payment methods for user #{current_user.email}..."

    begin
      # Use consistent customer ID format
      customer_id = "user_#{current_user.id}_#{current_user.email.gsub(/[^a-zA-Z0-9]/, '_')}"

      # Get all payment methods for this customer
      payment_sources = ChargeBee::PaymentSource.list({ customer_id: customer_id })

      stored_methods = []
      payment_sources.each do |ps|
        payment_method_id = ps.card&.id || ps.payment_source&.id
        status = ps.card&.status || ps.payment_source&.status

        if status == 'valid'
          # Get additional details
          begin
            payment_details = ChargeBee::PaymentSource.retrieve(payment_method_id)
            card_info = payment_details.card || payment_details.payment_source

            stored_methods << {
              id: payment_method_id,
              type: card_info.type,
              last4: card_info.last4,
              expiry_month: card_info.expiry_month,
              expiry_year: card_info.expiry_year,
              brand: card_info.brand,
              status: status
            }
          rescue => e
            Rails.logger.error "❌ Error getting payment method details: #{e.message}"
          end
        end
      end

      Rails.logger.info "✅ Found #{stored_methods.length} stored payment method(s)"
      return stored_methods

    rescue => e
      Rails.logger.error "❌ Error getting stored payment methods: #{e.message}"
      return []
    end
  end

  def build_plan_object(item_price)
    Rails.logger.info "🔍 Building plan object for item_price: #{item_price.id}"

    # Get the parent Item to display the cleaner plan name
    item_name = begin
      ChargeBee::Item.retrieve(item_price.item_id).item.name
    rescue => e
      Rails.logger.warn "⚠️ Could not retrieve item name for #{item_price.item_id}: #{e.message}"
      item_price.name
    end

    Rails.logger.info "✅ Creating OpenStruct for plan: #{item_name}"

    OpenStruct.new(
      id: item_price.item_id,
      name: item_name,
      description: "Clear and fair pricing for everyone. 10,000+ peoples are using it.",
      price: item_price.price.to_f / 100,
      billing_cycle: "#{item_price.period} #{item_price.period_unit}",
      period: item_price.period,
      period_unit: item_price.period_unit,
      status: item_price.status,
      chargebee_item_price_id: item_price.id,
      currency_code: item_price.currency_code
    )
  end

  # Sync Chargebee plan and subscription locally
  def sync_plan_and_subscription(subscription, plan_id)
    # Find the item price to get plan details
    item_price = find_item_price(plan_id)
    return unless item_price

    # Create or update plan
      plan = ChargebeePlan.find_or_initialize_by(chargebee_item_price_id: item_price.id)
      plan.chargebee_id = item_price.item_id
      plan.name = item_price.name
      plan.price = item_price.price.to_f / 100
      plan.billing_cycle = [item_price.period, item_price.period_unit].compact.join(' ')
      plan.status = item_price.status
      plan.save!

    # Create or update subscription
    sub_record = current_user.chargebee_subscriptions.find_or_initialize_by(chargebee_id: subscription.id)
    sub_record.update!(
      chargebee_plan: plan,
      status: subscription.status,
      current_term_start: Time.at(subscription.current_term_start),
      current_term_end: Time.at(subscription.current_term_end),
      trial_start: subscription.trial_start ? Time.at(subscription.trial_start) : nil,
      trial_end: subscription.trial_end ? Time.at(subscription.trial_end) : nil,
      metadata: subscription.try(:attributes) || {}
    )
  end

  # Find active subscription for a specific customer
  def find_active_subscription_for_customer(customer_id)
    Rails.logger.info "🔍 Looking for active subscription for customer: #{customer_id}"

    begin
      active_subs = ChargeBee::Subscription.list({
        customer_id: customer_id,
        status: { in: ['active', 'in_trial', 'non_renewing'] }
      })

      if active_subs.count > 0
        subscription = active_subs.first.subscription
        Rails.logger.info "✅ Found active subscription: #{subscription.id} (Status: #{subscription.status})"
        Rails.logger.info "🔍 Subscription customer ID: #{subscription.customer_id}"
        Rails.logger.info "🔍 Expected customer ID: #{customer_id}"

        # Verify the subscription actually belongs to this customer
        if subscription.customer_id != customer_id
          Rails.logger.warn "⚠️ Subscription customer mismatch! Subscription belongs to: #{subscription.customer_id}, but we're looking for: #{customer_id}"
          return nil
        end

        return subscription
      else
        Rails.logger.info "🔍 No active subscription found for customer"
        return nil
      end
    rescue => e
      Rails.logger.error "❌ Error finding active subscription: #{e.message}"
      return nil
    end
  end

  # Find valid payment method for a customer
  def find_valid_payment_method_for_customer(customer_id)

    begin
      # First, check if the customer has any active subscriptions with payment methods
      active_subs = ChargeBee::Subscription.list({
        customer_id: customer_id,
        status: { in: ['active', 'in_trial', 'non_renewing'] }
      })

      if active_subs.count > 0
        subscription = active_subs.first.subscription
        if subscription.payment_source_id
          return subscription.payment_source_id
        end
      end

      # If no payment method from subscription, check all payment sources
      payment_sources = ChargeBee::PaymentSource.list({ customer_id: customer_id })

      payment_sources.each_with_index do |ps, index|
        payment_method_id = ps.card&.id || ps.payment_source&.id
        status = ps.card&.status || ps.payment_source&.status

        if status == 'valid'
          Rails.logger.info "✅ Found valid payment method: #{payment_method_id}"
          return payment_method_id
        end
      end

      Rails.logger.warn "⚠️ No valid payment method found for customer"
      return nil
    rescue => e
      Rails.logger.error "❌ Error finding valid payment method: #{e.message}"
      return nil
    end
  end
end
