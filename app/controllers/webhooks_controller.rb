class WebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token

  def chargebee
    event = JSON.parse(request.body.read)
    event_type = event["event_type"]

    Rails.logger.info "📨 Received Chargebee webhook: #{event_type}"

    case event_type
    when "subscription_cancelled"
      handle_subscription_cancelled(event)
    when "item_created", "item_updated", "item_deleted"
      handle_plan_changes(event)
    when "subscription_created", "subscription_updated"
      handle_subscription_changes(event)
    when "feature_created", "feature_updated", "feature_deleted"
      handle_feature_changes(event)
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
end
