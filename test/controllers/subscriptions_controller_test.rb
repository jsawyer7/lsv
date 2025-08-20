require "test_helper"

class SubscriptionsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get subscriptions_index_url
    assert_response :success
  end

  test "should get show" do
    get subscriptions_show_url
    assert_response :success
  end

  test "should get create" do
    get subscriptions_create_url
    assert_response :success
  end

  test "should get cancel" do
    get subscriptions_cancel_url
    assert_response :success
  end

  test "should get reactivate" do
    get subscriptions_reactivate_url
    assert_response :success
  end
end
