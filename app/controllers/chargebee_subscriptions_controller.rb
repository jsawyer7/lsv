class ChargebeeSubscriptionsController < ApplicationController
  before_action :authenticate_user!

  def create
    provided_id = params[:plan_id]
    Rails.logger.info "🚀 Starting subscription creation for user: #{current_user.email}"
    Rails.logger.info "🚀 Plan ID provided: #{provided_id}"

    # Resolve plan ItemPrice
    item_price = find_item_price(provided_id)
    unless item_price
      Rails.logger.error "❌ Plan not found for ID: #{provided_id}"
      redirect_to subscription_settings_path, alert: "Plan not found or unavailable."
      return
    end

    Rails.logger.info "✅ Found item price: #{item_price.name} (#{item_price.id})"

    # Find the real active subscription from Chargebee (not just local DB)
    current_sub = find_active_subscription_from_chargebee

    Rails.logger.info "🔍 Looking for existing subscription for user: #{current_user.email}"
    Rails.logger.info "🔍 Found subscription: #{current_sub ? 'YES' : 'NO'}"

    if current_sub.present?
      Rails.logger.info "🔄 User has existing subscription - updating in-place"
      # User already has a subscription → update it in-place
      begin
        cancel_other_active_subscriptions(current_sub.id)

        update_result = ChargeBee::Subscription.update_for_items(
          current_sub.id,
          {
            replace_items_list: true,
            subscription_items: [{ item_price_id: item_price.id, quantity: 1 }],
            proration_option: 'prorate'
          }
        )

        sync_plan_and_subscription(update_result.subscription, item_price)

        redirect_to subscription_settings_path, notice: "Subscription updated successfully"
      rescue => e
        Rails.logger.error "Failed to update subscription: #{e.message}"
        redirect_to subscription_settings_path, alert: "Could not update subscription. Please contact support."
      end
    else
      Rails.logger.info "🆕 New user - sending to hosted checkout"
      Rails.logger.info "🆕 User details: #{current_user.email}, Name: #{current_user.full_name}"

      # First-time subscription → Hosted checkout
      full_name = current_user.full_name.to_s.strip
      first_name, last_name = full_name.split(" ", 2)
      first_name ||= "User"
      last_name ||= ""

      Rails.logger.info "🆕 Creating hosted checkout with:"
      Rails.logger.info "   - Item Price ID: #{item_price.id}"
      Rails.logger.info "   - Customer Email: #{current_user.email}"
      Rails.logger.info "   - Customer Name: #{first_name} #{last_name}"
      Rails.logger.info "   - Redirect URL: #{success_chargebee_subscriptions_url}"
      Rails.logger.info "   - Cancel URL: #{root_url}"

      begin
        result = ChargeBee::HostedPage.checkout_new_for_items({
          subscription_items: [{ item_price_id: item_price.id, quantity: 1 }],
          customer: { email: current_user.email, first_name: first_name, last_name: last_name },
          redirect_url: success_chargebee_subscriptions_url,
          cancel_url: root_url
        })

        Rails.logger.info "✅ Hosted checkout created successfully"
        Rails.logger.info "✅ Redirecting to: #{result.hosted_page.url}"

        redirect_to result.hosted_page.url, allow_other_host: true
      rescue => e
        Rails.logger.error "❌ Failed to create hosted checkout: #{e.message}"
        Rails.logger.error "❌ Error class: #{e.class}"
        Rails.logger.error "❌ Error backtrace: #{e.backtrace.first(5).join("\n")}"
        redirect_to subscription_settings_path, alert: "Could not create checkout. Please try again or contact support."
      end
    end
  end

  def success
    Rails.logger.info "🎉 Success callback received"
    Rails.logger.info "🎉 Hosted page ID: #{params[:id]}"

    begin
      hosted_page = ChargeBee::HostedPage.retrieve(params[:id]).hosted_page
      Rails.logger.info "✅ Retrieved hosted page successfully"

      subscription = hosted_page.content.subscription
      Rails.logger.info "✅ Subscription ID: #{subscription.id}"

      plan_price_id = subscription.subscription_items&.first&.item_price_id
      Rails.logger.info "✅ Plan price ID: #{plan_price_id}"

      item_price = ChargeBee::ItemPrice.retrieve(plan_price_id).item_price rescue nil
      if item_price
        Rails.logger.info "✅ Retrieved item price: #{item_price.name}"
      else
        Rails.logger.error "❌ Could not retrieve item price for ID: #{plan_price_id}"
      end

      sync_plan_and_subscription(subscription, item_price)
      Rails.logger.info "✅ Synced plan and subscription successfully"

      redirect_to subscription_settings_path, notice: "Subscription successful"
    rescue => e
      Rails.logger.error "❌ Error in success callback: #{e.message}"
      Rails.logger.error "❌ Error backtrace: #{e.backtrace.first(5).join("\n")}"
      redirect_to subscription_settings_path, alert: "There was an issue processing your subscription. Please contact support."
    end
  end

  private

  # Find item price by either item_price_id or item_id
  def find_item_price(provided_id)
    Rails.logger.info "🔍 Finding item price for ID: #{provided_id}"

    begin
      Rails.logger.info "🔍 Trying to retrieve as item_price_id..."
      item_price = ChargeBee::ItemPrice.retrieve(provided_id).item_price
      Rails.logger.info "✅ Found item price by ID: #{item_price.name} (#{item_price.id})"
      return item_price
    rescue => e
      Rails.logger.info "❌ Not found as item_price_id, trying as item_id..."
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

  # Sync Chargebee plan and subscription locally
  def sync_plan_and_subscription(subscription, item_price)
    if item_price
      plan = ChargebeePlan.find_or_initialize_by(chargebee_item_price_id: item_price.id)
      plan.chargebee_id = item_price.item_id
      plan.name = item_price.name
      plan.price = item_price.price.to_f / 100
      plan.billing_cycle = [item_price.period, item_price.period_unit].compact.join(' ')
      plan.status = item_price.status
      plan.save!
    else
      plan = nil
    end

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
end
