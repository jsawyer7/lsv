#!/usr/bin/env ruby

# Standalone script to test Chargebee connection and fetch plans
# Usage: ruby scripts/fetch_chargebee_plans.rb

require 'net/http'
require 'json'
require 'base64'

class ChargebeePlanFetcher
  def initialize
    @site = ENV['CHARGEBEE_SITE']
    @api_key = ENV['CHARGEBEE_API_KEY']
    @base_url = "https://#{@site}.chargebee.com/api/v2"

    puts "🔧 Configuration:"
    puts "   Site: #{@site}"
    puts "   API Key: #{@api_key ? "#{@api_key[0..7]}..." : "NOT SET"}"
    puts "   Base URL: #{@base_url}"
    puts ""
  end

  def test_connection
    puts "🔍 Testing Chargebee connection..."

    begin
      response = make_request(:get, '/items?limit=1')

      if response.code == '200'
        puts "✅ Connection successful!"
        data = JSON.parse(response.body)
        puts "📊 API Response keys: #{data.keys.join(', ')}"
        return true
      else
        puts "❌ Connection failed: #{response.code}"
        puts "Response body: #{response.body}"
        return false
      end

    rescue => e
      puts "❌ Connection error: #{e.message}"
      return false
    end
  end

  def fetch_plans
    puts "📋 Fetching plans from Chargebee..."

    begin
      # Fetch items (plans)
      puts "  📦 Fetching items..."
      items_response = make_request(:get, '/items?item_type[is]=plan')

      if items_response.code == '200'
        items_data = JSON.parse(items_response.body)
        puts "  ✅ Found #{items_data['list']&.count || 0} items"

        items_data['list']&.each do |item_data|
          item = item_data['item']
          puts "    📦 Item: #{item['name']} (ID: #{item['id']})"

          # Fetch item prices for this item
          prices_response = make_request(:get, "/item_prices?item_id[is]=#{item['id']}")

          if prices_response.code == '200'
            prices_data = JSON.parse(prices_response.body)

            if prices_data['list']&.any?
              prices_data['list'].each do |price_data|
                item_price = price_data['item_price']
                puts "      💵 Price: #{item_price['name']} - $#{item_price['price']/100.0} (#{item_price['currency_code']})"
                puts "         ID: #{item_price['id']}"
                puts "         Period: #{item_price['period']} #{item_price['period_unit']}"
                puts "         Status: #{item_price['status']}"
                puts ""
              end
            else
              puts "      ⚠️ No prices found for this item"
            end
          else
            puts "      ❌ Failed to fetch prices: #{prices_response.code}"
          end
        end
      else
        puts "  ❌ Failed to fetch items: #{items_response.code}"
      end

      # Also fetch all item prices directly
      puts "  💰 Fetching all item prices..."
      prices_response = make_request(:get, '/item_prices')

      if prices_response.code == '200'
        prices_data = JSON.parse(prices_response.body)
        puts "  ✅ Found #{prices_data['list']&.count || 0} item prices"

        prices_data['list']&.each do |price_data|
          item_price = price_data['item_price']
          puts "    💵 Price: #{item_price['name']} (ID: #{item_price['id']})"
          puts "       Item ID: #{item_price['item_id']}"
          puts "       Price: $#{item_price['price']/100.0} (#{item_price['currency_code']})"
          puts "       Period: #{item_price['period']} #{item_price['period_unit']}"
          puts "       Status: #{item_price['status']}"
          puts ""
        end
      else
        puts "  ❌ Failed to fetch item prices: #{prices_response.code}"
      end

    rescue => e
      puts "❌ Error fetching plans: #{e.message}"
      puts e.backtrace.first(5).join("\n")
    end
  end

  private

  def make_request(method, endpoint, data = {})
    uri = URI("#{@base_url}#{endpoint}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    if method == :get
      request = Net::HTTP::Get.new(uri)
    else
      request = Net::HTTP::Post.new(uri)
      request.body = data.to_json
    end

    request['Authorization'] = "Basic #{Base64.strict_encode64("#{@api_key}:")}"
    request['Content-Type'] = 'application/json'
    request['Accept'] = 'application/json'

    http.request(request)
  end
end

# Load environment variables if .env file exists
if File.exist?('.env')
  File.readlines('.env').each do |line|
    next if line.strip.empty? || line.start_with?('#')
    key, value = line.split('=', 2)
    ENV[key.strip] = value.strip if key && value
  end
end

# Run the script
fetcher = ChargebeePlanFetcher.new

if fetcher.test_connection
  puts ""
  fetcher.fetch_plans
else
  puts "❌ Cannot proceed without a successful connection"
  exit 1
end
