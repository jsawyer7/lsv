class SyncChargebeePlansJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "🔄 Starting automatic Chargebee plans sync..."

    begin
      service = ChargebeeService.new

      # Track which plans we're syncing
      synced_plan_ids = []

      # Fetch plans from Chargebee
      items_response = service.fetch_plans

      if items_response && items_response['list']
        Rails.logger.info "✅ Found #{items_response['list'].count} items in Chargebee"

        items_response['list'].each do |item_data|
          item = item_data['item']

          # Fetch item prices for this item
          prices_response = service.get("/item_prices?item_id[is]=#{item['id']}")

          if prices_response.code == '200'
            prices_data = JSON.parse(prices_response.body)

            if prices_data['list']
              prices_data['list'].each do |price_data|
                item_price = price_data['item_price']

                # Fetch entitlements/features for this plan
                entitlements = fetch_plan_entitlements(item_price['id'], item['name'])

                # Create or update plan in local database
                plan = ChargebeePlan.find_or_initialize_by(chargebee_item_price_id: item_price['id'])
                plan.assign_attributes(
                  chargebee_id: item['id'],
                  name: item_price['name'] || item['name'],
                  description: item['description'],
                  price: item_price['price'].to_f / 100,
                  billing_cycle: [item_price['period'], item_price['period_unit']].compact.join(' '),
                  status: item_price['status'],
                  metadata: {
                    item_data: item,
                    item_price_data: item_price,
                    entitlements: entitlements
                  }
                )

                if plan.save
                  synced_plan_ids << plan.id
                  Rails.logger.info "✅ Synced plan: #{plan.name}"
                else
                  Rails.logger.error "❌ Failed to save plan: #{plan.errors.full_messages.join(', ')}"
                end
              end
            end
          end
        end
      end

      # Clean up old plans
      old_plans = ChargebeePlan.where.not(id: synced_plan_ids)
      if old_plans.any?
        Rails.logger.info "🧹 Removing #{old_plans.count} old plans"

        # Handle dependencies
        old_plan_ids = old_plans.pluck(:id)
        old_subscriptions = ChargebeeSubscription.where(chargebee_plan_id: old_plan_ids)

        if old_subscriptions.any?
          old_subscription_ids = old_subscriptions.pluck(:id)
          old_billings = ChargebeeBilling.where(chargebee_subscription_id: old_subscription_ids)
          old_billings.destroy_all if old_billings.any?
          old_subscriptions.destroy_all
        end

        old_plans.destroy_all
      end

      # Update cache timestamp
      Rails.cache.write('chargebee_plans_last_synced', Time.current, expires_in: 1.day)

      Rails.logger.info "🎉 Chargebee plans sync completed successfully!"

    rescue => e
      Rails.logger.error "❌ Error in Chargebee plans sync: #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")
      raise e
    end
  end

  private

  def fetch_plan_entitlements(item_price_id, plan_name)
    entitlements = []

    begin
      # Method 1: Try to get entitlements from existing subscriptions
      subscriptions = ChargeBee::Subscription.list({
        status: 'active',
        limit: 100
      })

      feature_ids = Set.new

      subscriptions.each do |sub_response|
        subscription = sub_response.subscription

        if subscription.subscription_items&.any? { |item| item.item_price_id == item_price_id }
          begin
            subscription_entitlements = ChargeBee::SubscriptionEntitlement.subscription_entitlements_for_subscription(subscription.id)

            subscription_entitlements.each do |entitlement_response|
              entitlement = entitlement_response.subscription_entitlement
              feature_ids.add(entitlement.feature_id)
            end
          rescue => e
            # Skip if we can't get entitlements for this subscription
          end
        end
      end

      # Method 2: Use plan-based mapping if no entitlements found
      if feature_ids.empty?
        feature_ids = get_plan_feature_mapping(plan_name)
      end

      # Convert feature IDs to entitlement objects
      feature_ids.each do |feature_id|
        begin
          feature = ChargeBee::Feature.retrieve(feature_id).feature
          entitlements << {
            'feature_id' => feature.id,
            'feature_name' => feature.name,
            'description' => feature.description,
            'value' => 'included'
          }
        rescue => e
          # Skip if we can't get feature details
        end
      end

    rescue => e
      Rails.logger.warn "⚠️ Could not fetch entitlements: #{e.message}"
    end

    entitlements
  end

  def get_plan_feature_mapping(plan_name)
    case plan_name&.downcase
    when /free/
      ['read_facts', 'read_theories', 'read_source_books', 'like_content', 'comment_content']
    when /plus/
      ['read_facts', 'read_theories', 'read_source_books', 'like_content', 'comment_content',
       'create_claims', 'ai_study_assist', 'follow_leaders', 'follow_groups']
    when /premium/
      ['read_facts', 'read_theories', 'read_source_books', 'like_content', 'comment_content',
       'create_claims', 'create_theories', 'submit_challenges', 'ai_study_assist', 'ai_challenge',
       'source_study_ai', 'follow_leaders', 'follow_groups']
    else
      ['read_facts', 'read_theories', 'read_source_books']
    end
  end
end
