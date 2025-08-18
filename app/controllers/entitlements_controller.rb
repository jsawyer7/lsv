class EntitlementsController < ApplicationController
  before_action :authenticate_user!

  def index
    # Get the current user's subscription ID
    current_subscription = current_user.chargebee_subscriptions
      .where(status: %w[active in_trial non_renewing])
      .order(updated_at: :desc, created_at: :desc)
      .first

    if current_subscription&.chargebee_id
      begin
        # Fetch entitlements from Chargebee using the subscription ID
        result = ChargeBee::SubscriptionEntitlement.subscription_entitlements_for_subscription(
          current_subscription.chargebee_id
        )

        @entitlements = result.map do |item|
          {
            feature_id: item.subscription_entitlement.feature_id,
            feature_name: item.subscription_entitlement.feature_name,
            value: item.subscription_entitlement.value
          }
        end

        Rails.logger.info "✅ Fetched #{@entitlements.count} entitlements for user: #{current_user.email}"
        render json: @entitlements
      rescue => e
        Rails.logger.error "❌ Error fetching entitlements: #{e.message}"
        render json: { error: "Failed to fetch entitlements" }, status: :internal_server_error
      end
    else
      Rails.logger.info "ℹ️ No active subscription found for user: #{current_user.email}"
      render json: { error: "No active subscription found" }, status: :not_found
    end
  end

  def show
    # Get entitlements for a specific plan (for display purposes)
    plan_name = params[:plan_name]

    if plan_name
      # For plans without subscription, show default entitlements
      entitlements = get_default_plan_entitlements(plan_name)

      @entitlements = entitlements.map.with_index do |entitlement, index|
        {
          feature_id: "default_#{index}",
          feature_name: entitlement,
          value: "included"
        }
      end

      render json: @entitlements
    else
      render json: { error: "Plan name required" }, status: :bad_request
    end
  end

  private

  def get_default_plan_entitlements(plan_name)
    case plan_name&.downcase
    when /basic/
      [
        "Basic Claims Creation",
        "Community Access",
        "Limited AI Evidence (5/month)",
        "Basic Support",
        "Standard Response Time"
      ]
    when /plus/
      [
        "Everything in Basic",
        "Unlimited Claims",
        "Enhanced AI Evidence (25/month)",
        "Priority Support",
        "Faster Response Time",
        "Advanced Analytics"
      ]
    when /premium/
      [
        "Everything in Plus",
        "Unlimited AI Evidence",
        "Premium Support",
        "24/7 Response Time",
        "Custom Integrations",
        "Dedicated Account Manager"
      ]
    else
      [
        "Basic Features",
        "Standard Support"
      ]
    end
  end
end
