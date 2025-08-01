require "test_helper"

class WebhooksControllerTest < ActionDispatch::IntegrationTest
  test "should get chargebee" do
    get webhooks_chargebee_url
    assert_response :success
  end
end
