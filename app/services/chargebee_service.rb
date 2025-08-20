require 'net/http'
require 'json'

class ChargebeeService
  
  def initialize
    @site = ENV['CHARGEBEE_SITE']
    @api_key = ENV['CHARGEBEE_API_KEY']
    @base_url = "https://#{@site}.chargebee.com/api/v2"
  end

  # Plan Management (Product Catalog 2.0)
  def fetch_plans
    response = get('/items?item_type[is]=plan')
    handle_response(response)
  end

  def fetch_item_prices
    response = get('/item_prices')
    handle_response(response)
  end

  def create_plan(plan_data)
    response = post('/items', plan_data)
    handle_response(response)
  end

  def update_plan(plan_id, plan_data)
    response = post("/items/#{plan_id}", plan_data)
    handle_response(response)
  end

  def create_item_price(item_price_data)
    response = post('/item_prices', item_price_data)
    handle_response(response)
  end

  # Customer Management
  def create_customer(customer_data)
    response = post('/customers', customer_data)
    handle_response(response)
  end

  def update_customer(customer_id, customer_data)
    response = post("/customers/#{customer_id}", customer_data)
    handle_response(response)
  end

  def fetch_customer(customer_id)
    response = get("/customers/#{customer_id}")
    handle_response(response)
  end

  # Subscription Management (Product Catalog 2.0)
  def create_subscription(subscription_data)
    # For Product Catalog 2.0, we need to use item_price_id instead of plan_id
    # But since we don't have item prices, we'll use the hosted checkout page approach
    response = post('/hosted_pages/checkout_new', subscription_data)
    handle_response(response)
  end

  def update_subscription(subscription_id, subscription_data)
    response = post("/subscriptions/#{subscription_id}", subscription_data)
    handle_response(response)
  end

  def cancel_subscription(subscription_id, options = {})
    data = { subscription: { end_of_term: options[:end_of_term] || false } }
    response = post("/subscriptions/#{subscription_id}/cancel", data)
    handle_response(response)
  end

  def reactivate_subscription(subscription_id)
    response = post("/subscriptions/#{subscription_id}/reactivate")
    handle_response(response)
  end

  def fetch_subscription(subscription_id)
    response = get("/subscriptions/#{subscription_id}")
    handle_response(response)
  end

  # Hosted Pages
  def create_checkout_page(subscription_data)
    response = post('/hosted_pages/checkout_new', subscription_data)
    handle_response(response)
  end

  def create_portal_session(customer_id, options = {})
    data = { customer_id: customer_id }.merge(options)
    response = post('/portal_sessions', data)
    handle_response(response)
  end

  # Webhook Verification
  def verify_webhook(payload, signature)
    expected_signature = OpenSSL::HMAC.hexdigest('sha256', webhook_secret, payload)
    signature == expected_signature
  end

  # Public HTTP methods for testing
  def get(endpoint)
    make_request(:get, endpoint)
  end

  def post(endpoint, data = {})
    make_request(:post, endpoint, data)
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
    
    response = http.request(request)
    response
  end

  def handle_response(response)
    case response.code.to_i
    when 200, 201
      JSON.parse(response.body)
    else
      raise "Chargebee API Error: #{response.code} - #{response.body}"
    end
  end

  def webhook_secret
    ENV['CHARGEBEE_WEBHOOK_SECRET']
  end
end 