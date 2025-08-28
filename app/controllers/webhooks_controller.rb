class WebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token

  def chargebee
    signature = request.headers["x-chargebee-signature"]
    payload = request.raw_post

    unless valid_signature?(payload, signature)
      Rails.logger.error "❌ Invalid webhook signature"
      return head :unauthorized
    end

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
      handle_plan_changes(event)
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

    head :ok
  end

  private

  def handle_subscription_cancelled(event)
    subscription_id = event.dig("content", "subscription", "id")
    sub = ChargebeeSubscription.find_by(chargebee_id: subscription_id)
    sub&.update(status: "cancelled")
    Rails.logger.info "✅ Handled subscription cancelled: #{subscription_id}"
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

  private

  # Chargebee docs show HMAC SHA256 using the webhook signing key
  def valid_signature?(payload, header)
    return false if header.blank?

    begin
      timestamp, signature = header.split(",").map { |kv| kv.split("=", 2)[1] }
      secret = ENV.fetch("CHARGEBEE_WEBHOOK_SIGNING_KEY")

      computed = OpenSSL::HMAC.hexdigest("SHA256", secret, "#{timestamp}#{payload}")
      ActiveSupport::SecurityUtils.secure_compare(computed, signature)
    rescue => e
      Rails.logger.error "❌ Error validating webhook signature: #{e.message}"
      false
    end
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
      billing.update!(
        user: subscription.user,
        plan_name: subscription.chargebee_plan&.name,
        purchase_date: Time.at(invoice_data["date"]),
        ending_date: Time.at(invoice_data["due_date"]) if invoice_data["due_date"],
        status: invoice_data["status"],
        amount: invoice_data["total"].to_f / 100,
        currency: invoice_data["currency_code"],
        description: "Invoice for #{subscription.chargebee_plan&.name}",
        metadata: invoice_data
      )
    end
  end
end
