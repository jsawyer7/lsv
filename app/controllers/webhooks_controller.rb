class WebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :verify_webhook_signature
  
  def chargebee
    event_type = params[:event_type]
    event_data = params[:content]
    
    case event_type
    when 'subscription_created'
      handle_subscription_created(event_data)
    when 'subscription_cancelled'
      handle_subscription_cancelled(event_data)
    when 'subscription_reactivated'
      handle_subscription_reactivated(event_data)
    when 'subscription_renewed'
      handle_subscription_renewed(event_data)
    when 'payment_succeeded'
      handle_payment_succeeded(event_data)
    when 'payment_failed'
      handle_payment_failed(event_data)
    when 'customer_created'
      handle_customer_created(event_data)
    when 'customer_changed'
      handle_customer_changed(event_data)
    else
      Rails.logger.info "Unhandled webhook event: #{event_type}"
    end
    
    head :ok
  end
  
  private
  
  def verify_webhook_signature
    payload = request.body.read
    signature = request.headers['X-Chargebee-Request-Signature']
    
    chargebee_service = ChargebeeService.new
    unless chargebee_service.verify_webhook(payload, signature)
      Rails.logger.error "Invalid webhook signature"
      head :unauthorized
      return
    end
    
    # Reset the request body for Rails to parse params
    request.body.rewind
  end
  
  def handle_subscription_created(event_data)
    subscription_data = event_data['subscription']
    customer_data = event_data['customer']
    
    # Find or create customer
    customer = Customer.find_by(chargebee_id: customer_data['id'])
    unless customer
      user = User.find_by(email: customer_data['email'])
      if user
        customer = user.create_customer!(
          chargebee_id: customer_data['id'],
          email: customer_data['email'],
          first_name: customer_data['first_name'],
          last_name: customer_data['last_name'],
          metadata: customer_data
        )
      end
    end
    
    # Find plan
    plan = Plan.find_by(chargebee_id: subscription_data['plan_id'])
    
    # Create subscription
    if customer&.user && plan
      customer.user.subscriptions.create!(
        chargebee_id: subscription_data['id'],
        plan: plan,
        status: subscription_data['status'],
        current_term_start: Time.at(subscription_data['current_term_start']),
        current_term_end: Time.at(subscription_data['current_term_end']),
        trial_start: subscription_data['trial_start'] ? Time.at(subscription_data['trial_start']) : nil,
        trial_end: subscription_data['trial_end'] ? Time.at(subscription_data['trial_end']) : nil,
        metadata: subscription_data
      )
    end
  end
  
  def handle_subscription_cancelled(event_data)
    subscription_data = event_data['subscription']
    subscription = Subscription.find_by(chargebee_id: subscription_data['id'])
    
    if subscription
      subscription.update(
        status: subscription_data['status'],
        current_term_end: Time.at(subscription_data['current_term_end'])
      )
    end
  end
  
  def handle_subscription_reactivated(event_data)
    subscription_data = event_data['subscription']
    subscription = Subscription.find_by(chargebee_id: subscription_data['id'])
    
    if subscription
      subscription.update(
        status: subscription_data['status'],
        current_term_start: Time.at(subscription_data['current_term_start']),
        current_term_end: Time.at(subscription_data['current_term_end'])
      )
    end
  end
  
  def handle_subscription_renewed(event_data)
    subscription_data = event_data['subscription']
    subscription = Subscription.find_by(chargebee_id: subscription_data['id'])
    
    if subscription
      subscription.update(
        current_term_start: Time.at(subscription_data['current_term_start']),
        current_term_end: Time.at(subscription_data['current_term_end'])
      )
    end
  end
  
  def handle_payment_succeeded(event_data)
    # Handle successful payment
    Rails.logger.info "Payment succeeded for subscription: #{event_data['subscription']['id']}"
  end
  
  def handle_payment_failed(event_data)
    subscription_data = event_data['subscription']
    subscription = Subscription.find_by(chargebee_id: subscription_data['id'])
    
    if subscription
      subscription.update(status: 'past_due')
    end
  end
  
  def handle_customer_created(event_data)
    customer_data = event_data['customer']
    user = User.find_by(email: customer_data['email'])
    
    if user && !user.customer
      user.create_customer!(
        chargebee_id: customer_data['id'],
        email: customer_data['email'],
        first_name: customer_data['first_name'],
        last_name: customer_data['last_name'],
        metadata: customer_data
      )
    end
  end
  
  def handle_customer_changed(event_data)
    customer_data = event_data['customer']
    customer = Customer.find_by(chargebee_id: customer_data['id'])
    
    if customer
      customer.update(
        email: customer_data['email'],
        first_name: customer_data['first_name'],
        last_name: customer_data['last_name'],
        metadata: customer_data
      )
    end
  end
end
