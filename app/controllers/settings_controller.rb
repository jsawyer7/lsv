require 'ostruct'
require 'set'

class SettingsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_user
  layout 'dashboard'

  def edit
    # @user is set by before_action
  end

  def update
    # @user is set by before_action
    # Remove avatar if requested
    if params[:remove_avatar] == "true"
      @user.avatar.purge
    elsif params[:user] && params[:user][:avatar]
      @user.avatar.attach(params[:user][:avatar])
    end

    # Remove background image if requested
    if params[:remove_background_image] == "true"
      @user.background_image.purge
    elsif params[:user] && params[:user][:background_image]
      @user.background_image.attach(params[:user][:background_image])
    end

    if params[:user] && @user.update(user_params.except(:avatar, :background_image))
      redirect_to edit_settings_path, notice: 'Profile updated successfully.'
    else
      render :edit
    end
  end

  def notifications
    render :notifications
  end

    def subscription
    @plans = []

    begin
      # Try to get plans from cache first
      cached_plans = Rails.cache.read('chargebee_plans')

      if cached_plans && cache_fresh?
        Rails.logger.info "✅ Using cached plans"
        @plans = cached_plans
      else
        Rails.logger.info "🔄 Cache expired or missing, fetching fresh plans"

        # Use plans from local database (which we synced with features)
        local_plans = ChargebeePlan.where(status: 'active').order(:price)

        if local_plans.any?
          Rails.logger.info "✅ Using #{local_plans.count} plans from local database with features"

          local_plans.each do |local_plan|
            # Build plan object from local database
            plan = OpenStruct.new(
              id: local_plan.chargebee_id,
              name: clean_plan_name(local_plan.name),
              description: local_plan.description,
              price: local_plan.price,
              billing_cycle: local_plan.billing_cycle,
              period: local_plan.billing_cycle&.split(' ')&.first,
              period_unit: local_plan.billing_cycle&.split(' ')&.last,
              status: local_plan.status,
              chargebee_item_price_id: local_plan.chargebee_item_price_id,
              features: local_plan.feature_descriptions,
              feature_descriptions: local_plan.feature_descriptions
            )

            @plans << plan
          end

          # Cache the plans for 1 hour
          Rails.cache.write('chargebee_plans', @plans, expires_in: 1.hour)
          Rails.logger.info "✅ Plans cached for 1 hour"
        else
          Rails.logger.info "⚠️ No local plans found, triggering sync job"
          SyncChargebeePlansJob.perform_later

          # Return empty plans for now, they'll be available on next request
          @plans = []
        end
      end

      # Sort by price ascending to resemble Basic → Pro → Premium
      @plans.sort_by! { |p| p.price.to_f }

    rescue => e
      Rails.logger.error "Error fetching plans: #{e.message}"
      @plans = []
      Rails.logger.info "No plans available - API error"
    end

    # Pick the most recent subscription that is effectively current
    @current_subscription = current_user
      .chargebee_subscriptions
      .where(status: %w[active in_trial non_renewing])
      .order(updated_at: :desc, created_at: :desc)
      .first
    render :subscription
  end

  def billing
    # Get billing history from local database first
    @billing_history = current_user.chargebee_billings.recent

    # If no local data exists or data is stale, sync from Chargebee
    if @billing_history.empty? || billing_data_stale?
      sync_billing_data_from_chargebee
      @billing_history = current_user.chargebee_billings.recent
    end

    render :billing
  end

  def billing_data_stale?
    # Consider data stale if it's older than 1 hour
    last_billing = current_user.chargebee_billings.order(updated_at: :desc).first
    last_billing.nil? || last_billing.updated_at < 1.hour.ago
  end

  def refresh_billing
    sync_billing_data_from_chargebee
    redirect_to billing_settings_path, notice: "Billing history refreshed successfully."
  end

  def sync_billing_data_from_chargebee
    begin
      # Get customer ID from user's subscriptions
      customer_id = get_chargebee_customer_id

      if customer_id
        # Fetch invoices for this customer from Chargebee
        invoices = ChargeBee::Invoice.list({
          customer_id: customer_id,
          limit: 50
        })

        invoices.each do |invoice_response|
          invoice = invoice_response.invoice

          # Get subscription details for this invoice
          subscription = nil
          if invoice.subscription_id
            begin
              subscription_response = ChargeBee::Subscription.retrieve(invoice.subscription_id)
              subscription = subscription_response.subscription
            rescue => e
              Rails.logger.warn "Could not fetch subscription #{invoice.subscription_id}: #{e.message}"
            end
          end

          # Get plan name from subscription
          plan_name = if subscription&.subscription_items&.any?
            item_price_id = subscription.subscription_items.first.item_price_id
            begin
              item_price_response = ChargeBee::ItemPrice.retrieve(item_price_id)
              item_response = ChargeBee::Item.retrieve(item_price_response.item_price.item_id)
              item_response.item.name
            rescue => e
              Rails.logger.warn "Could not fetch plan name for #{item_price_id}: #{e.message}"
              "Subscription"
            end
          else
            "Subscription"
          end

          # Find or create local subscription record
          local_subscription = current_user.chargebee_subscriptions.find_by(chargebee_id: invoice.subscription_id) if invoice.subscription_id

          # Create or update billing record in local database
          billing_record = current_user.chargebee_billings.find_or_initialize_by(chargebee_id: invoice.id)
          billing_record.assign_attributes(
            chargebee_subscription: local_subscription,
            plan_name: plan_name,
            purchase_date: Time.at(invoice.date),
            ending_date: subscription ? Time.at(subscription.current_term_end) : Time.at(invoice.date),
            status: invoice.status,
            amount: invoice.total.to_f / 100,
            currency: invoice.currency_code,
            description: "Subscription payment",
            metadata: {
              subscription_id: invoice.subscription_id,
              invoice_data: {
                id: invoice.id,
                date: invoice.date,
                total: invoice.total,
                status: invoice.status,
                currency_code: invoice.currency_code,
                subscription_id: invoice.subscription_id
              }
            }
          )
          billing_record.save!
        end

        Rails.logger.info "Successfully synced #{invoices.count} billing records for user #{current_user.id}"
      end
    rescue => e
      Rails.logger.error "Error syncing billing data: #{e.message}"
    end
  end

  def plan_details
    plan_id = params[:id]

    begin
      # First try to get plan from local database
      local_plan = ChargebeePlan.find_by(chargebee_item_price_id: plan_id)

      if local_plan
        Rails.logger.info "✅ Using plan from local database: #{local_plan.name}"

                  # Build plan object from local database
          @plan = OpenStruct.new(
            id: local_plan.chargebee_id,
            name: clean_plan_name(local_plan.name),
            description: local_plan.description || "Clear and fair pricing for everyone. 10,000+ peoples are using it.",
            price: local_plan.price,
            billing_cycle: local_plan.billing_cycle,
            period: local_plan.billing_cycle&.split(' ')&.first,
            period_unit: local_plan.billing_cycle&.split(' ')&.last,
            status: local_plan.status,
            chargebee_item_price_id: local_plan.chargebee_item_price_id,
            features: local_plan.feature_descriptions,
            feature_descriptions: local_plan.feature_descriptions
          )
      else
        Rails.logger.info "⚠️ Plan not found in local database, fetching from Chargebee API"

        # Fallback to Chargebee API
        item_price = ChargeBee::ItemPrice.retrieve(plan_id)

        # Get the parent Item to display the cleaner plan name
        item_name = begin
          ChargeBee::Item.retrieve(item_price.item_price.item_id).item.name
        rescue => _e
          item_price.item_price.name
        end

        # Get feature descriptions from Chargebee entitlements
        feature_descriptions = get_plan_feature_descriptions(item_name)

        # Build plan object for the view
        @plan = OpenStruct.new(
          id: item_price.item_price.item_id,
          name: item_name,
          description: "Clear and fair pricing for everyone. 10,000+ peoples are using it.",
          price: item_price.item_price.price.to_f / 100,
          billing_cycle: "#{item_price.item_price.period} #{item_price.item_price.period_unit}",
          period: item_price.item_price.period,
          period_unit: item_price.item_price.period_unit,
          status: item_price.item_price.status,
          chargebee_item_price_id: item_price.item_price.id,
          features: feature_descriptions,
          feature_descriptions: feature_descriptions
        )
      end

      # Check if this is the current user's plan
      @current_subscription = current_user
        .chargebee_subscriptions
        .where(status: %w[active in_trial non_renewing])
        .order(updated_at: :desc, created_at: :desc)
        .first

      @is_current_plan = @current_subscription&.chargebee_plan&.chargebee_item_price_id == @plan.chargebee_item_price_id

    rescue => e
      Rails.logger.error "Error fetching plan details: #{e.message}"
              redirect_to subscription_settings_path, alert: "The selected plan is not available at this time. Please try again or contact support."
      return
    end

    render :plan_details, layout: 'dashboard'
  end

  def cancel_subscription
    plan_id = params[:id]

    begin
      # Find the current user's active subscription
      current_subscription = current_user
        .chargebee_subscriptions
        .where(status: %w[active in_trial non_renewing])
        .order(updated_at: :desc, created_at: :desc)
        .first

      unless current_subscription
        redirect_to subscription_settings_path, alert: "No active subscription found. Please select a plan to continue."
        return
      end

      # Verify this is the correct plan being cancelled
      if current_subscription.chargebee_plan&.chargebee_item_price_id != plan_id
        redirect_to subscription_settings_path, alert: "There was a mismatch with the selected plan. Please try again or contact support."
        return
      end

      Rails.logger.info "Cancelling subscription #{current_subscription.chargebee_id} for user #{current_user.email}"

      # Cancel the subscription in Chargebee using Product Catalog 2.0 API
      cancel_result = ChargeBee::Subscription.cancel_for_items(current_subscription.chargebee_id, {
        end_of_term: true,  # Cancel at the end of current billing period
        replace_items_list: true,
        subscription_items: []  # Empty array to remove all items
      })

      # Update local subscription record
      current_subscription.update!(
        status: 'cancelled'
      )

      Rails.logger.info "Successfully cancelled subscription #{current_subscription.chargebee_id}"

      redirect_to subscription_settings_path, notice: "Your subscription has been cancelled and will end at the end of your current billing period."

    rescue => e
      Rails.logger.error "Error cancelling subscription: #{e.message}"
      redirect_to subscription_settings_path, alert: "We couldn't cancel your subscription at this time. Please try again or contact our support team."
    end
  end

  def download_invoice
    invoice_id = params[:id]

    begin
      # Get the invoice from Chargebee
      invoice_response = ChargeBee::Invoice.retrieve(invoice_id)
      invoice = invoice_response.invoice

      # Get subscription details
      subscription = nil
      if invoice.subscription_id
        subscription_response = ChargeBee::Subscription.retrieve(invoice.subscription_id)
        subscription = subscription_response.subscription
      end

      # Get plan name
      plan_name = if subscription&.subscription_items&.any?
        item_price_id = subscription.subscription_items.first.item_price_id
        begin
          item_price_response = ChargeBee::ItemPrice.retrieve(item_price_id)
          item_response = ChargeBee::Item.retrieve(item_price_response.item_price.item_id)
          item_response.item.name
        rescue => e
          "Subscription"
        end
      else
        "Subscription"
      end

      # Generate PDF content
      pdf_content = generate_invoice_pdf(invoice, subscription, plan_name)

      # Send PDF as download
      send_data pdf_content,
                filename: "invoice_#{invoice_id}.pdf",
                type: 'application/pdf',
                disposition: 'attachment'

    rescue => e
      Rails.logger.error "Error generating invoice PDF: #{e.message}"
      redirect_to billing_settings_path, alert: "Could not generate invoice PDF. Please try again."
    end
  end

  # Fetch all features from Chargebee
  def fetch_all_chargebee_features
    begin
      # Use the proper ChargeBee::Feature API to list all features
      features = ChargeBee::Feature.list({ limit: 50 })

      all_features = features.map do |feature_response|
        feature = feature_response.feature
        {
          name: feature.name,
          description: feature.description,
          id: feature.id
        }
      end

      Rails.logger.info "✅ Successfully fetched #{all_features.count} features from Chargebee"
      all_features

    rescue => e
      Rails.logger.error "❌ Error fetching all features: #{e.message}"
      # Return empty array if we can't fetch features
      []
    end
  end

  # Default features for unknown plans
  def get_default_plan_features(plan_name)
    case plan_name&.downcase
    when /basic/
      [
        "Basic Claims Creation",
        "Community Access",
        "Limited AI Evidence (5/month)",
        "Basic Support"
      ]
    when /plus/
      [
        "Everything in Basic",
        "Unlimited Claims",
        "Enhanced AI Evidence (25/month)",
        "Priority Support",
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
        "Basic Claims Creation",
        "Community Access",
        "Limited AI Evidence (5/month)",
        "Basic Support"
      ]
    end
  end

  def get_plan_feature_descriptions(plan_name)
    begin
      # Get dynamic feature mapping based on actual entitlements from existing subscriptions
      plan_feature_ids = get_plan_entitlements_from_subscriptions(plan_name)

      if plan_feature_ids.any?
        # Fetch all features and filter by the entitlement-based IDs
        all_features = fetch_all_chargebee_features
        all_features.select { |feature| plan_feature_ids.include?(feature[:id]) }
                    .map { |feature| feature[:description] }
                    .compact
      else
        # Fallback to default features if no entitlements found
        Rails.logger.warn "⚠️ No entitlements found for plan: #{plan_name}, using defaults"
        get_default_plan_features(plan_name)
      end

    rescue => e
      Rails.logger.error "❌ Error fetching feature descriptions from Chargebee: #{e.message}"
      # Fallback to default feature descriptions
      return get_default_plan_features(plan_name)
    end
  end

  # Get entitlements for a plan by analyzing existing subscriptions
  def get_plan_entitlements_from_subscriptions(plan_name)
    begin
      # Get the item_price_id for this plan
      item_price_id = get_item_price_id_for_plan(plan_name)
      return [] unless item_price_id

      Rails.logger.info "🔍 Fetching entitlements for plan: #{plan_name} (item_price_id: #{item_price_id})"

      # Get all active subscriptions
      subscriptions = ChargeBee::Subscription.list({
        status: 'active',
        limit: 100
      })

      feature_ids = Set.new

      # Find subscriptions for this specific plan and extract their entitlements
      subscriptions.each do |sub_response|
        subscription = sub_response.subscription

        # Check if this subscription has the specific item_price_id
        if subscription.subscription_items&.any? { |item| item.item_price_id == item_price_id }
          Rails.logger.info "  ✅ Found subscription #{subscription.id} for plan #{plan_name}"

          begin
            # Get entitlements for this subscription
            entitlements = ChargeBee::SubscriptionEntitlement.subscription_entitlements_for_subscription(subscription.id)

            entitlements.each do |entitlement_response|
              entitlement = entitlement_response.subscription_entitlement
              feature_ids.add(entitlement.feature_id)
              Rails.logger.info "    - Added entitlement: #{entitlement.feature_id} (value: #{entitlement.value})"
            end
          rescue => e
            Rails.logger.warn "⚠️ Could not get entitlements for subscription #{subscription.id}: #{e.message}"
          end
        end
      end

      result = feature_ids.to_a
      Rails.logger.info "✅ Found #{result.count} entitlements for plan #{plan_name}: #{result}"
      result

    rescue => e
      Rails.logger.error "❌ Error fetching entitlements for plan #{plan_name}: #{e.message}"
      # Fallback to hardcoded mapping if dynamic fetching fails
      get_fallback_plan_feature_mapping(plan_name)
    end
  end

  # Get item_price_id for a given plan name
  def get_item_price_id_for_plan(plan_name)
    case plan_name&.downcase
    when /premium/
      'premium-USD-Monthly'
    when /plus/
      'plus-USD-Monthly'
    when /basic|free/
      'test-basic-plan-USD-Monthly'
    else
      nil
    end
  end

  # Fallback mapping if dynamic entitlement fetching fails
  def get_fallback_plan_feature_mapping(plan_name)
    case plan_name&.downcase
    when /premium/
      ['premiumwala', 'premium-he', 'lalala']
    when /plus/
      ['plus', 'plus-he']
    when /basic|free/
      ['bbbb', 'han', 'free-wla', 'freee-he']
    else
      []
    end
  end

  private
  def set_user
    @user = current_user
  end

  def user_params
    params.require(:user).permit(:full_name, :phone, :email, :about, :avatar, :avatar_cache, :remove_avatar, :background_image, :remove_background_image)
  end

  def clean_plan_name(plan_name)
    # Remove common suffixes like "USD Monthly", "USD-Monthly", etc.
    plan_name.gsub(/\s*(USD|USD-)?\s*(Monthly|Yearly|Annually)/i, '').strip
  end

  def cache_fresh?
    last_synced = Rails.cache.read('chargebee_plans_last_synced')
    last_synced && last_synced > 1.hour.ago
  end

  def get_chargebee_customer_id
    begin
      # Get customer ID from user's most recent subscription
      current_subscription = current_user
        .chargebee_subscriptions
        .where(status: %w[active in_trial non_renewing])
        .order(updated_at: :desc, created_at: :desc)
        .first

      if current_subscription
        # Get customer details from Chargebee using subscription ID
        subscription_response = ChargeBee::Subscription.retrieve(current_subscription.chargebee_id)
        subscription_response.subscription.customer_id
      else
        Rails.logger.warn "No active subscription found for user #{current_user.id}"
        nil
      end
    rescue => e
      Rails.logger.error "Error getting Chargebee customer ID: #{e.message}"
      nil
    end
  end

  private

  def generate_invoice_pdf(invoice, subscription, plan_name)
    require 'prawn'
    require 'prawn/table'

    Prawn::Document.new do |pdf|
      # Header
      pdf.text "VeriFaith", size: 24, style: :bold, align: :center
      pdf.move_down 10
      pdf.text "INVOICE", size: 18, align: :center
      pdf.move_down 20

      # Invoice details
      pdf.text "Invoice #: #{invoice.id}", size: 12
      pdf.text "Date: #{Time.at(invoice.date).strftime('%B %d, %Y')}", size: 12
      pdf.text "Status: #{invoice.status.titleize}", size: 12
      pdf.move_down 20

      # Customer info
      pdf.text "Bill To:", size: 14, style: :bold
      pdf.text current_user.full_name || current_user.email, size: 12
      pdf.text current_user.email, size: 12
      pdf.move_down 20

      # Plan details
      pdf.text "Plan Details:", size: 14, style: :bold
      pdf.text "Plan: #{plan_name}", size: 12
      if subscription
        pdf.text "Period: #{Time.at(subscription.current_term_start).strftime('%B %d, %Y')} - #{Time.at(subscription.current_term_end).strftime('%B %d, %Y')}", size: 12
      end
      pdf.move_down 20

      # Amount
      pdf.text "Amount: $#{'%.2f' % (invoice.total.to_f / 100)}", size: 16, style: :bold
      pdf.text "Currency: #{invoice.currency_code}", size: 12

      # Footer
      pdf.move_down 40
      pdf.text "Thank you for your business!", size: 12, align: :center
      pdf.text "VeriFaith - Making faith verification accessible", size: 10, align: :center, color: "666666"
    end.render
  end
end
