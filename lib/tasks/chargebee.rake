namespace :chargebee do
  desc "Sync plans from Chargebee"
  task sync_plans: :environment do
    puts "Syncing plans from Chargebee..."
    
    begin
      chargebee_service = ChargebeeService.new
      response = chargebee_service.fetch_plans
      
      items_data = response['list']
      
      items_data.each do |item_data|
        item = item_data['item']
        
        # Only process items that are plans
        next unless item['type'] == 'plan'
        
        puts "Processing item: #{item['name']} (type: #{item['type']})"
        
        # Find or create plan
        local_plan = Plan.find_or_initialize_by(chargebee_id: item['id'])
        
        # Update plan attributes
        local_plan.assign_attributes(
          name: item['name'],
          description: item['description'] || item['name'],
          price: 0.0, # We'll need to fetch item prices separately
          billing_cycle: 'monthly', # Default, we'll need to get this from item prices
          status: item['status'],
          metadata: {
            features: extract_features(item),
            chargebee_data: item
          }
        )
        
        if local_plan.save
          puts "✓ Synced plan: #{item['name']} (#{item['id']})"
        else
          puts "✗ Failed to sync plan: #{item['name']} - #{local_plan.errors.full_messages.join(', ')}"
        end
      end
      
      puts "Plan sync completed!"
      
    rescue => e
      puts "Error syncing plans: #{e.message}"
      puts e.backtrace.first(5).join("\n")
    end
  end
  
  desc "Sync item prices from Chargebee"
  task sync_item_prices: :environment do
    puts "Syncing item prices from Chargebee..."
    
    begin
      chargebee_service = ChargebeeService.new
      response = chargebee_service.fetch_item_prices
      
      item_prices_data = response['list']
      
      item_prices_data.each do |item_price_data|
        item_price = item_price_data['item_price']
        
        puts "Processing item price: #{item_price['id']} for item: #{item_price['item_id']}"
        
        # Find the corresponding plan
        plan = Plan.find_by(chargebee_id: item_price['item_id'])
        
        if plan
          # Update plan with item price information
          plan.update(
            price: item_price['price'] / 100.0, # Convert from cents
            billing_cycle: item_price['period_unit'],
            metadata: plan.metadata.merge({
              item_price_id: item_price['id'],
              item_price_data: item_price
            })
          )
          puts "✓ Updated plan: #{plan.name} with price: $#{plan.price} (#{plan.billing_cycle})"
        else
          puts "⚠ Plan not found for item: #{item_price['item_id']}"
        end
      end
      
      puts "Item prices sync completed!"
      
    rescue => e
      puts "Error syncing item prices: #{e.message}"
      puts e.backtrace.first(5).join("\n")
    end
  end

  desc "Sync subscriptions from Chargebee"
  task sync_subscriptions: :environment do
    puts "Syncing subscriptions from Chargebee..."
    
    # This would require iterating through all customers and their subscriptions
    # For now, we'll rely on webhooks for real-time updates
    puts "Subscription sync relies on webhooks for real-time updates."
    puts "Use webhooks to keep subscriptions in sync automatically."
  end
  
  desc "Create item prices for existing plans"
  task create_item_prices: :environment do
    puts "Creating item prices for existing plans..."
    
    begin
      chargebee_service = ChargebeeService.new
      
      Plan.all.each do |plan|
        puts "Creating item price for plan: #{plan.name}"
        
        # Create item price data
        # Set default prices if not set
        price = plan.price > 0 ? plan.price : case plan.name.downcase
          when 'premium' then 19.99
          when 'plus' then 9.99
          when 'free user' then 0.0
          else 0.0
        end
        
        item_price_data = {
          id: "#{plan.chargebee_id}_price",
          item_id: plan.chargebee_id,
          name: "#{plan.name} Price",
          price: (price * 100).to_i, # Convert to cents
          period_unit: plan.billing_cycle,
          period: 1,
          status: 'active'
        }
        
        response = chargebee_service.create_item_price(item_price_data)
        
        # Update plan with item price ID
        plan.update(
          metadata: plan.metadata.merge({
            item_price_id: response['item_price']['id'],
            item_price_data: response['item_price']
          })
        )
        
        puts "✓ Created item price for: #{plan.name} (ID: #{response['item_price']['id']})"
      end
      
      puts "Item prices creation completed!"
      
    rescue => e
      puts "Error creating item prices: #{e.message}"
      puts e.backtrace.first(5).join("\n")
    end
  end

  desc "Create sample plans for testing"
  task create_sample_plans: :environment do
    puts "Creating sample plans..."
    
    plans = [
      {
        chargebee_id: 'Free-User',
        name: 'Free User',
        description: 'Perfect for getting started with fact-checking',
        price: 0.0,
        billing_cycle: 'monthly',
        status: 'active',
        metadata: {
          features: {
            'basic_claims' => true,
            'limited_ai_evidence' => true,
            'community_access' => true,
            'unlimited_claims' => false,
            'advanced_ai_evidence' => false,
            'priority_support' => false
          }
        }
      },
      {
        chargebee_id: 'Plus',
        name: 'Plus',
        description: 'Enhanced features for serious fact-checkers',
        price: 9.99,
        billing_cycle: 'monthly',
        status: 'active',
        metadata: {
          features: {
            'basic_claims' => true,
            'limited_ai_evidence' => true,
            'community_access' => true,
            'unlimited_claims' => true,
            'advanced_ai_evidence' => true,
            'priority_support' => false
          }
        }
      },
      {
        chargebee_id: 'premium',
        name: 'Premium',
        description: 'Full access to all features and priority support',
        price: 19.99,
        billing_cycle: 'monthly',
        status: 'active',
        metadata: {
          features: {
            'basic_claims' => true,
            'limited_ai_evidence' => true,
            'community_access' => true,
            'unlimited_claims' => true,
            'advanced_ai_evidence' => true,
            'priority_support' => true
          }
        }
      }
    ]
    
    plans.each do |plan_attrs|
      plan = Plan.find_or_initialize_by(chargebee_id: plan_attrs[:chargebee_id])
      plan.assign_attributes(plan_attrs)
      
      if plan.save
        puts "✓ Created/Updated plan: #{plan.name}"
      else
        puts "✗ Failed to create plan: #{plan.name} - #{plan.errors.full_messages.join(', ')}"
      end
    end
    
    puts "Sample plans created!"
  end
  
  private
  
  def extract_features(item)
    # Extract features from item metadata or addons
    features = {}
    
    # Add basic features based on item type
    if item['type'] == 'plan'
      features['basic_claims'] = true
      features['limited_ai_evidence'] = true
      features['community_access'] = true
      
      # Add premium features for higher-tier plans
      if item['name']&.downcase&.include?('premium')
        features['unlimited_claims'] = true
        features['advanced_ai_evidence'] = true
        features['priority_support'] = true
      elsif item['name']&.downcase&.include?('plus')
        features['unlimited_claims'] = true
        features['advanced_ai_evidence'] = true
      end
    end
    
    features
  end
end 