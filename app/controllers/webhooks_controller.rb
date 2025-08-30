class WebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :authenticate_webhook

  def chargebee
    # Test endpoint for debugging
    if params[:test] == 'true'
      Rails.logger.info "🧪 Webhook test endpoint hit"
      return render json: { status: 'test_received', timestamp: Time.current }
    end

    payload = request.raw_post
    event = JSON.parse(payload)
    event_type = event["event_type"]

    Rails.logger.info "📨 Received Chargebee webhook: #{event_type}"

    case event_type
    when "subscription_cancelled"
      handle_subscription_cancelled(event)
    when "subscription_created"
      handle_subscription_created(event)
    when "subscription_updated"
      handle_subscription_changes(event)
    when "item_created", "item_updated", "item_deleted"
      handle_item_changes(event)
    when "item_price_created", "item_price_updated", "item_price_deleted"
      handle_item_price_changes(event)
    when "feature_created", "feature_updated", "feature_deleted"
      handle_feature_changes(event)
    when "invoice_generated"
      handle_invoice_generated(event)
    when "payment_succeeded"
      handle_payment_succeeded(event)
    when "payment_failed"
      handle_payment_failed(event)
    else
      Rails.logger.info "ℹ️ Unhandled webhook event: #{event_type}"
    end

    Rails.logger.info "✅ Webhook processed successfully"
    head :ok
  rescue => e
    Rails.logger.error "❌ Webhook processing error: #{e.message}"
    Rails.logger.error e.backtrace.first(5).join("\n")
    head :internal_server_error
  end

  def health_check
    last_sync = Rails.cache.read('chargebee_plans_last_synced')
    webhook_status = {
      endpoint: '/webhooks/chargebee',
      last_sync: last_sync,
      chargebee_site: ENV['CHARGEBEE_SITE'],
      status: 'healthy'
    }

    render json: webhook_status
  end

  private

  def authenticate_webhook
    # Skip authentication for test requests
    return if params[:test] == 'true'

    # Get credentials from environment variables
    expected_username = ENV['CHARGEBEE_WEBHOOK_USERNAME'] || 'webhook'
    expected_password = ENV['CHARGEBEE_WEBHOOK_PASSWORD'] || 'verifaith2025'

    # Extract credentials from request
    auth_header = request.headers['Authorization']

    if auth_header && auth_header.start_with?('Basic ')
      # Decode basic auth credentials
      credentials = Base64.decode64(auth_header.split(' ').last)
      username, password = credentials.split(':')

      if username == expected_username && password == expected_password
        Rails.logger.info "✅ Webhook authentication successful"
        return
      end
    end

    Rails.logger.error "❌ Webhook authentication failed"
    head :unauthorized
  end

  def handle_subscription_cancelled(event)
    subscription_id = event.dig("content", "subscription", "id")
    sub = ChargebeeSubscription.find_by(chargebee_id: subscription_id)
    sub&.update(status: "cancelled")
    Rails.logger.info "✅ Handled subscription cancelled: #{subscription_id}"
  end

  def handle_item_changes(event)
    event_type = event["event_type"]
    item_data = event.dig("content", "item")

    Rails.logger.info "🔄 Item changes detected: #{event_type}"

    if item_data
      item_id = item_data["id"]
      item_name = item_data["name"]
      Rails.logger.info "📦 Item: #{item_name} (ID: #{item_id})"

      # Log specific changes for item_updated
      if event_type == "item_updated"
        Rails.logger.info "💰 Item price/plan updated - triggering sync..."

        # Get the updated item prices
        begin
          prices_response = ChargeBee::ItemPrice.list({ item_id: item_id, status: 'active' })
          if prices_response && prices_response.any?
            prices_response.each do |price_response|
              item_price = price_response.item_price
              Rails.logger.info "💵 Price: $#{item_price.price.to_f / 100}/#{item_price.period_unit} (ID: #{item_price.id})"
            end
          end
        rescue => e
          Rails.logger.error "❌ Error fetching item prices: #{e.message}"
        end
      end
    end

    # Trigger the sync job to update plans in our database
    Rails.logger.info "🔄 Triggering plan sync job..."
    SyncChargebeePlansJob.perform_later
  end

  def handle_item_price_changes(event)
    event_type = event["event_type"]
    item_price_data = event.dig("content", "item_price")

    Rails.logger.info "💰 Item price changes detected: #{event_type}"

    if item_price_data
      item_price_id = item_price_data["id"]
      item_price_name = item_price_data["name"]
      item_price_amount = item_price_data["price"]
      item_price_currency = item_price_data["currency_code"]
      item_price_period = item_price_data["period_unit"]

      Rails.logger.info "💵 Price Details:"
      Rails.logger.info "   Name: #{item_price_name}"
      Rails.logger.info "   Amount: #{item_price_amount} #{item_price_currency}"
      Rails.logger.info "   Period: #{item_price_period}"
      Rails.logger.info "   ID: #{item_price_id}"

      if event_type == "item_price_updated"
        Rails.logger.info "🔄 Item price updated - triggering sync..."
      elsif event_type == "item_price_created"
        Rails.logger.info "🆕 New item price created - triggering sync..."
      elsif event_type == "item_price_deleted"
        Rails.logger.info "🗑️ Item price deleted - triggering sync..."
      end
    end

    # Trigger the sync job to update plans in our database
    Rails.logger.info "🔄 Triggering plan sync job..."
    SyncChargebeePlansJob.perform_later
  end

  def handle_plan_changes(event)
    Rails.logger.info "🔄 Plan changes detected, triggering sync..."
    SyncChargebeePlansJob.perform_later
  end

  def handle_subscription_changes(event)
    Rails.logger.info "🔄 Subscription changes detected, triggering sync..."
    SyncChargebeePlansJob.perform_later
  end

  def handle_feature_changes(event)
    Rails.logger.info "🔄 Feature changes detected, triggering sync..."
    SyncChargebeePlansJob.perform_later
  end

  def handle_subscription_created(event)
    subscription_id = event.dig("content", "subscription", "id")
    customer_email = event.dig("content", "subscription", "customer_email")

    Rails.logger.info "🎉 New subscription created: #{subscription_id} for #{customer_email}"

    # Find user by email and sync subscription
    user = User.find_by(email: customer_email)
    if user
      begin
        subscription = event.dig("content", "subscription")
        item_price_id = subscription.dig("subscription_items", 0, "item_price_id")

        if item_price_id
          item_price = ChargeBee::ItemPrice.retrieve(item_price_id).item_price
          sync_plan_and_subscription_for_user(user, subscription, item_price)
          Rails.logger.info "✅ Synced new subscription for user: #{user.email}"
        end
      rescue => e
        Rails.logger.error "❌ Error syncing new subscription: #{e.message}"
      end
    else
      Rails.logger.warn "⚠️ User not found for email: #{customer_email}"
    end
  end

  def handle_invoice_generated(event)
    invoice_id = event.dig("content", "invoice", "id")
    subscription_id = event.dig("content", "invoice", "subscription_id")

    Rails.logger.info "📄 Invoice generated: #{invoice_id} for subscription: #{subscription_id}"

    # Sync invoice data
    sync_invoice_data(event.dig("content", "invoice"))
  end

  def handle_payment_succeeded(event)
    payment_id = event.dig("content", "transaction", "id")
    subscription_id = event.dig("content", "transaction", "subscription_id")

    Rails.logger.info "✅ Payment succeeded: #{payment_id} for subscription: #{subscription_id}"

    # Update subscription status if needed
    if subscription_id
      subscription = ChargebeeSubscription.find_by(chargebee_id: subscription_id)
      subscription&.update(status: "active")
    end
  end

  def handle_payment_failed(event)
    payment_id = event.dig("content", "transaction", "id")
    subscription_id = event.dig("content", "transaction", "subscription_id")

    Rails.logger.info "❌ Payment failed: #{payment_id} for subscription: #{subscription_id}"

    # Handle failed payment - could send notification, update status, etc.
  end

  def sync_plan_and_subscription_for_user(user, subscription, item_price)
    # Create or update plan
    plan = ChargebeePlan.find_or_initialize_by(chargebee_item_price_id: item_price.id)
    plan.chargebee_id = item_price.item_id
    plan.name = item_price.name
    plan.price = item_price.price.to_f / 100
    plan.billing_cycle = [item_price.period, item_price.period_unit].compact.join(' ')
    plan.status = item_price.status
    plan.save!

    # Create or update subscription
    sub_record = user.chargebee_subscriptions.find_or_initialize_by(chargebee_id: subscription["id"])
    sub_record.update!(
      chargebee_plan: plan,
      status: subscription["status"],
      current_term_start: Time.at(subscription["current_term_start"]),
      current_term_end: Time.at(subscription["current_term_end"]),
      trial_start: subscription["trial_start"] ? Time.at(subscription["trial_start"]) : nil,
      trial_end: subscription["trial_end"] ? Time.at(subscription["trial_end"]) : nil,
      metadata: subscription
    )
  end

  def sync_invoice_data(invoice_data)
    return unless invoice_data

    subscription_id = invoice_data["subscription_id"]
    subscription = ChargebeeSubscription.find_by(chargebee_id: subscription_id)

    if subscription
      billing = subscription.chargebee_billings.find_or_initialize_by(chargebee_id: invoice_data["id"])

      # Prepare billing attributes
      billing_attributes = {
        user: subscription.user,
        plan_name: subscription.chargebee_plan&.name,
        purchase_date: Time.at(invoice_data["date"]),
        status: invoice_data["status"],
        amount: invoice_data["total"].to_f / 100,
        currency: invoice_data["currency_code"],
        description: "Invoice for #{subscription.chargebee_plan&.name}",
        metadata: invoice_data
      }

      # Add ending_date only if due_date exists
      if invoice_data["due_date"]
        billing_attributes[:ending_date] = Time.at(invoice_data["due_date"])
      end

      billing.update!(billing_attributes)
    end
  end
end
