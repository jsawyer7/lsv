namespace :chargebee do
  desc "Fetch and sync plans from Chargebee"
  task fetch_plans: :environment do
    puts "🔄 Fetching plans from Chargebee..."

    begin
      # Initialize Chargebee service
      service = ChargebeeService.new

      # Track which plans we're syncing to clean up old ones
      synced_plan_ids = []

      # Fetch plans (items) from Chargebee
      puts "📋 Fetching items (plans)..."
      items_response = service.fetch_plans

      if items_response && items_response['list']
        puts "✅ Found #{items_response['list'].count} items"

        items_response['list'].each do |item_data|
          item = item_data['item']
          puts "  📦 Processing item: #{item['name']} (ID: #{item['id']})"

          # Fetch item prices for this item
          puts "    💰 Fetching prices for item #{item['id']}..."
          prices_response = service.get("/item_prices?item_id[is]=#{item['id']}")

          if prices_response.code == '200'
            prices_data = JSON.parse(prices_response.body)

            if prices_data['list']
              prices_data['list'].each do |price_data|
                item_price = price_data['item_price']
                puts "      💵 Processing price: #{item_price['name']} (#{item_price['price']} #{item_price['currency_code']})"

                # Fetch entitlements/features for this plan
                puts "        🔍 Fetching entitlements for plan..."
                entitlements = fetch_plan_entitlements(item_price['id'], item['name'])
                puts "        ✅ Found #{entitlements.count} entitlements"

                # Create or update plan in local database
                plan = ChargebeePlan.find_or_initialize_by(chargebee_item_price_id: item_price['id'])
                plan.assign_attributes(
                  chargebee_id: item['id'],
                  name: item_price['name'] || item['name'],
                  description: item['description'],
                  price: item_price['price'].to_f / 100, # Convert from cents
                  billing_cycle: [item_price['period'], item_price['period_unit']].compact.join(' '),
                  status: item_price['status'],
                  metadata: {
                    item_data: item,
                    item_price_data: item_price,
                    entitlements: entitlements
                  }
                )

                if plan.save
                  puts "        ✅ Saved plan: #{plan.name}"
                  synced_plan_ids << plan.id
                else
                  puts "        ❌ Failed to save plan: #{plan.errors.full_messages.join(', ')}"
                end
              end
            else
              puts "      ⚠️ No prices found for item #{item['id']}"
            end
          else
            puts "      ❌ Failed to fetch prices for item #{item['id']}: #{prices_response.code}"
          end
        end
      else
        puts "❌ No items found or invalid response"
      end

      # Also fetch item prices directly to catch any missing ones
      puts "\n📋 Fetching all item prices..."
      prices_response = service.fetch_item_prices

      if prices_response && prices_response['list']
        puts "✅ Found #{prices_response['list'].count} item prices"

        prices_response['list'].each do |price_data|
          item_price = price_data['item_price']
          puts "  💵 Processing price: #{item_price['name']} (ID: #{item_price['id']})"

          # Get the associated item
          item_response = service.get("/items/#{item_price['item_id']}")
          if item_response.code == '200'
            item_data = JSON.parse(item_response.body)
            item = item_data['item']

            # Fetch entitlements/features for this plan
            puts "    🔍 Fetching entitlements for plan..."
            entitlements = fetch_plan_entitlements(item_price['id'], item['name'])
            puts "    ✅ Found #{entitlements.count} entitlements"

            # Create or update plan
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
              puts "    ✅ Saved plan: #{plan.name}"
              synced_plan_ids << plan.id unless synced_plan_ids.include?(plan.id)
            else
              puts "    ❌ Failed to save plan: #{plan.errors.full_messages.join(', ')}"
            end
          else
            puts "    ❌ Failed to fetch item #{item_price['item_id']}: #{item_response.code}"
          end
        end
      end

      # Clean up old plans that are no longer in Chargebee
      puts "\n🧹 Cleaning up old plans..."
      old_plans = ChargebeePlan.where.not(id: synced_plan_ids)
      if old_plans.any?
        puts "🗑️ Removing #{old_plans.count} old plans:"

        # First, remove billing records that reference subscriptions for these old plans
        old_plan_ids = old_plans.pluck(:id)
        old_subscriptions = ChargebeeSubscription.where(chargebee_plan_id: old_plan_ids)
        if old_subscriptions.any?
          old_subscription_ids = old_subscriptions.pluck(:id)
          old_billings = ChargebeeBilling.where(chargebee_subscription_id: old_subscription_ids)
          if old_billings.any?
            puts "  🗑️ Removing #{old_billings.count} billing records for old subscriptions..."
            old_billings.destroy_all
          end
          puts "  🗑️ Removing #{old_subscriptions.count} subscriptions for old plans..."
          old_subscriptions.destroy_all
        end

        old_plans.each do |plan|
          puts "  • #{plan.name} (ID: #{plan.chargebee_item_price_id})"
        end
        old_plans.destroy_all
        puts "✅ Old plans removed"
      else
        puts "✅ No old plans to clean up"
      end

      puts "\n🎉 Plan sync completed!"
      puts "📊 Total plans in database: #{ChargebeePlan.count}"

      # Display all plans with their entitlements
      puts "\n📋 Current plans in database:"
      ChargebeePlan.all.each do |plan|
        entitlements = plan.metadata&.dig('entitlements') || []
        puts "  • #{plan.name} - $#{plan.price} (#{plan.billing_cycle}) - #{plan.status}"
        if entitlements.any?
          puts "    Features:"
          entitlements.each do |entitlement|
            puts "      - #{entitlement['feature_name']}: #{entitlement['value']}"
          end
        else
          puts "    Features: None found"
        end
        puts ""
      end

    rescue => e
      puts "❌ Error fetching plans: #{e.message}"
      puts e.backtrace.first(5).join("\n")
    end
  end

  # Helper method to fetch entitlements for a plan
  def fetch_plan_entitlements(item_price_id, plan_name)
    entitlements = []

    begin
      # Method 1: Try to get entitlements from existing subscriptions with this plan
      subscriptions = ChargeBee::Subscription.list({
        status: 'active',
        limit: 100
      })

      feature_ids = Set.new

      subscriptions.each do |sub_response|
        subscription = sub_response.subscription

        # Check if this subscription has the specific item_price_id
        if subscription.subscription_items&.any? { |item| item.item_price_id == item_price_id }
          begin
            # Get entitlements for this subscription
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

      # Method 2: If no entitlements found from subscriptions, use plan-based mapping
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
      puts "    ⚠️ Could not fetch entitlements: #{e.message}"
    end

    entitlements
  end

  # Helper method to map plans to features
  def get_plan_feature_mapping(plan_name)
    case plan_name&.downcase
    when /free/
      # Free User plan - basic features
      [
        'read_facts',
        'read_theories',
        'read_source_books',
        'like_content',
        'comment_content'
      ]
    when /plus/
      # Plus plan - enhanced features
      [
        'read_facts',
        'read_theories',
        'read_source_books',
        'like_content',
        'comment_content',
        'create_claims',
        'ai_study_assist',
        'follow_leaders',
        'follow_groups'
      ]
    when /premium/
      # Premium plan - all features
      [
        'read_facts',
        'read_theories',
        'read_source_books',
        'like_content',
        'comment_content',
        'create_claims',
        'create_theories',
        'submit_challenges',
        'ai_study_assist',
        'ai_challenge',
        'source_study_ai',
        'follow_leaders',
        'follow_groups'
      ]
    else
      # Default - basic features
      [
        'read_facts',
        'read_theories',
        'read_source_books'
      ]
    end
  end

  desc "Safely sync plans without deleting existing subscriptions"
  task safe_sync: :environment do
    puts "🔄 Safely syncing plans from Chargebee..."

    begin
      service = ChargebeeService.new

      # Track which plans we're syncing
      synced_plan_ids = []

      # Fetch plans (items) from Chargebee
      puts "📋 Fetching items (plans)..."
      items_response = service.fetch_plans

      if items_response && items_response['list']
        puts "✅ Found #{items_response['list'].count} items"

        items_response['list'].each do |item_data|
          item = item_data['item']
          puts "  📦 Processing item: #{item['name']} (ID: #{item['id']})"

          # Fetch item prices for this item
          prices_response = service.get("/item_prices?item_id[is]=#{item['id']}")

          if prices_response.code == '200'
            prices_data = JSON.parse(prices_response.body)

            if prices_data['list']
              prices_data['list'].each do |price_data|
                item_price = price_data['item_price']
                puts "      💵 Processing price: #{item_price['name']} (#{item_price['price']} #{item_price['currency_code']})"

                # Fetch entitlements/features for this plan
                puts "        🔍 Fetching entitlements for plan..."
                entitlements = fetch_plan_entitlements(item_price['id'], item['name'])
                puts "        ✅ Found #{entitlements.count} entitlements"

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
                  puts "        ✅ Saved plan: #{plan.name}"
                  synced_plan_ids << plan.id
                else
                  puts "        ❌ Failed to save plan: #{plan.errors.full_messages.join(', ')}"
                end
              end
            end
          end
        end
      end

      # Also fetch item prices directly
      puts "\n📋 Fetching all item prices..."
      prices_response = service.fetch_item_prices

      if prices_response && prices_response['list']
        prices_response['list'].each do |price_data|
          item_price = price_data['item_price']

          # Get the associated item
          item_response = service.get("/items/#{item_price['item_id']}")
          if item_response.code == '200'
            item_data = JSON.parse(item_response.body)
            item = item_data['item']

            # Create or update plan
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
                item_price_data: item_price
              }
            )

            if plan.save
              synced_plan_ids << plan.id unless synced_plan_ids.include?(plan.id)
            end
          end
        end
      end

      # Only remove plans that have no subscriptions
      puts "\n🧹 Cleaning up unused plans..."
      old_plans = ChargebeePlan.where.not(id: synced_plan_ids)
      safe_to_delete = []

      old_plans.each do |plan|
        subscription_count = plan.chargebee_subscriptions.count
        if subscription_count == 0
          safe_to_delete << plan
          puts "  🗑️ Safe to remove: #{plan.name} (no subscriptions)"
        else
          # Check if any of these subscriptions have billing records
          total_billing_count = 0
          plan.chargebee_subscriptions.each do |subscription|
            total_billing_count += subscription.chargebee_billings.count
          end
          puts "  ⚠️ Keeping: #{plan.name} (#{subscription_count} subscriptions, #{total_billing_count} billing records)"
        end
      end

      if safe_to_delete.any?
        safe_to_delete.each(&:destroy)
        puts "✅ Removed #{safe_to_delete.count} unused plans"
      else
        puts "✅ No unused plans to remove"
      end

      puts "\n🎉 Safe sync completed!"
      puts "📊 Total plans in database: #{ChargebeePlan.count}"

      # Display all plans with their entitlements
      puts "\n📋 Current plans in database:"
      ChargebeePlan.all.each do |plan|
        subscription_count = plan.chargebee_subscriptions.count
        entitlements = plan.metadata&.dig('entitlements') || []
        puts "  • #{plan.name} - $#{plan.price} (#{plan.billing_cycle}) - #{plan.status} (#{subscription_count} subscriptions)"
        if entitlements.any?
          puts "    Features:"
          entitlements.each do |entitlement|
            puts "      - #{entitlement['feature_name']}: #{entitlement['value']}"
          end
        else
          puts "    Features: None found"
        end
        puts ""
      end

    rescue => e
      puts "❌ Error syncing plans: #{e.message}"
      puts e.backtrace.first(5).join("\n")
    end
  end

  desc "Clean up all plans and re-sync from Chargebee"
  task clean_and_sync: :environment do
    puts "🧹 Cleaning up all existing plans..."

    # Handle dependencies in the correct order
    billing_count = ChargebeeBilling.count
    if billing_count > 0
      puts "⚠️ Found #{billing_count} existing billing records"
      puts "🗑️ Removing billing records first..."
      ChargebeeBilling.destroy_all
      puts "✅ Billing records removed"
    end

    subscription_count = ChargebeeSubscription.count
    if subscription_count > 0
      puts "⚠️ Found #{subscription_count} existing subscriptions"
      puts "🗑️ Removing subscriptions..."
      ChargebeeSubscription.destroy_all
      puts "✅ Subscriptions removed"
    end

    # Now remove all plans
    plan_count = ChargebeePlan.count
    if plan_count > 0
      puts "⚠️ Found #{plan_count} existing plans"
      puts "🗑️ Removing plans..."
      ChargebeePlan.destroy_all
      puts "✅ All plans removed"
    end

    puts "\n🔄 Re-syncing from Chargebee..."
    Rake::Task['chargebee:fetch_plans'].invoke
  end

  desc "Test Chargebee connection"
  task test_connection: :environment do
    puts "🔍 Testing Chargebee connection..."

    begin
      service = ChargebeeService.new

      # Test basic API call
      response = service.get('/items?limit=1')

      if response.code == '200'
        puts "✅ Connection successful!"
        data = JSON.parse(response.body)
        puts "📊 API Response: #{data.keys.join(', ')}"
      else
        puts "❌ Connection failed: #{response.code} - #{response.body}"
      end

    rescue => e
      puts "❌ Connection error: #{e.message}"
    end
  end

  desc "Assign features to plans based on plan type"
  task assign_features: :environment do
    puts "🔧 Assigning features to plans..."

    ChargebeePlan.all.each do |plan|
      puts "📋 Processing plan: #{plan.name}"

      # Get feature mapping for this plan
      feature_ids = get_plan_feature_mapping(plan.name)
      entitlements = []

      feature_ids.each do |feature_id|
        begin
          feature = ChargeBee::Feature.retrieve(feature_id).feature
          entitlements << {
            'feature_id' => feature.id,
            'feature_name' => feature.name,
            'description' => feature.description,
            'value' => 'included'
          }
          puts "  ✅ Added: #{feature.name}"
        rescue => e
          puts "  ❌ Could not fetch feature #{feature_id}: #{e.message}"
        end
      end

      # Update plan metadata with entitlements
      current_metadata = plan.metadata || {}
      current_metadata['entitlements'] = entitlements
      plan.update!(metadata: current_metadata)

      puts "  📊 Total features assigned: #{entitlements.count}"
      puts ""
    end

    puts "🎉 Feature assignment completed!"
  end

  desc "Schedule daily Chargebee sync (for production)"
  task schedule_sync: :environment do
    puts "📅 Scheduling daily Chargebee sync..."

    # This would typically be done with a job scheduler like Sidekiq-Scheduler
    # For now, we'll just run the sync immediately
    puts "🔄 Running sync now..."
    SyncChargebeePlansJob.perform_later

    puts "✅ Sync job queued successfully!"
    puts "💡 In production, set up a cron job or scheduler to run this daily"
  end

  desc "Fetch all features from Chargebee"
  task fetch_features: :environment do
    puts "🔍 Fetching all features from Chargebee..."

    begin
      features = ChargeBee::Feature.list({ limit: 100 })

      if features.any?
        puts "✅ Found #{features.count} features:"
        features.each do |feature_response|
          feature = feature_response.feature
          puts "  • #{feature.name} (ID: #{feature.id})"
          puts "    Description: #{feature.description}"
          puts "    Type: #{feature.type}"
          puts "    Unit: #{feature.unit}"
          puts ""
        end
      else
        puts "❌ No features found in Chargebee"
      end

    rescue => e
      puts "❌ Error fetching features: #{e.message}"
      puts e.backtrace.first(5).join("\n")
    end
  end

  desc "List all plans in database"
  task list_plans: :environment do
    puts "📋 Plans in database:"

    if ChargebeePlan.count == 0
      puts "  No plans found. Run 'rake chargebee:fetch_plans' to sync from Chargebee."
    else
      ChargebeePlan.all.each do |plan|
        entitlements = plan.metadata&.dig('entitlements') || []
        puts "  • #{plan.name}"
        puts "    ID: #{plan.chargebee_id}"
        puts "    Price ID: #{plan.chargebee_item_price_id}"
        puts "    Price: $#{plan.price} (#{plan.billing_cycle})"
        puts "    Status: #{plan.status}"
        puts "    Description: #{plan.description}"
        if entitlements.any?
          puts "    Features:"
          entitlements.each do |entitlement|
            puts "      - #{entitlement['feature_name']}: #{entitlement['value']}"
            puts "        Description: #{entitlement['description']}" if entitlement['description'].present?
          end
        else
          puts "    Features: None found"
        end
        puts ""
      end
    end
  end

  desc "List all payment methods with customer information"
  task list_all_payment_methods: :environment do
    puts "🔍 Listing all payment methods with customer information..."

    begin
      all_payment_sources = ChargeBee::PaymentSource.list({ limit: 100 })
      puts "✅ Found #{all_payment_sources.length} payment methods total"
      puts ""

      all_payment_sources.each_with_index do |ps, index|
        payment_method_id = ps.card&.id || ps.payment_source&.id
        status = ps.card&.status || ps.payment_source&.status

        begin
          payment_details = ChargeBee::PaymentSource.retrieve(payment_method_id)
          customer_id = payment_details.card&.customer_id || payment_details.payment_source&.customer_id
          last4 = payment_details.card&.last4 || payment_details.payment_source&.last4
          brand = payment_details.card&.brand || payment_details.payment_source&.brand

          puts "#{index + 1}. #{payment_method_id}"
          puts "   Status: #{status}"
          puts "   Customer: #{customer_id}"
          puts "   Card: #{brand&.titleize} ****#{last4}"
          puts ""
        rescue => e
          puts "#{index + 1}. #{payment_method_id} (Error getting details: #{e.message})"
          puts ""
        end
      end
    rescue => e
      puts "❌ Error: #{e.message}"
    end
  end

  desc "Check payment methods for a specific customer"
  task :check_payment_methods, [:customer_id] => :environment do |t, args|
    customer_id = args[:customer_id]
    if customer_id.blank?
      puts "❌ Please provide a customer ID: rails chargebee:check_payment_methods[customer_id]"
      exit 1
    end

    puts "🔍 Checking payment methods for customer: #{customer_id}"

    begin
      payment_sources = ChargeBee::PaymentSource.list({ customer_id: customer_id })
      puts "✅ Found #{payment_sources.length} payment method(s) for customer #{customer_id}"

      payment_sources.each_with_index do |ps, index|
        payment_method_id = ps.card&.id || ps.payment_source&.id
        status = ps.card&.status || ps.payment_source&.status
        puts "  #{index + 1}. #{payment_method_id} (Status: #{status})"
      end
    rescue => e
      puts "❌ Error: #{e.message}"
    end
  end
end
