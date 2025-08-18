class WebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token

  def chargebee
    event = JSON.parse(request.body.read)

    case event["event_type"]
    when "subscription_cancelled"
      subscription_id = event.dig("content", "subscription", "id")
      sub = ChargebeeSubscription.find_by(chargebee_id: subscription_id)
      sub&.update(status: "cancelled")
    end

    head :ok
  end
end
