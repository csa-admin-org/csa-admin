# frozen_string_literal: true

require "test_helper"

class API::V1::BasketsControllerTest < ActionDispatch::IntegrationTest
  def request(delivery_id:, api_token: nil)
    api_token ||= Current.org.api_token
    authorization = ActionController::HttpAuthentication::Token.encode_credentials(api_token)
    headers = {
      "ACCEPT" => "text/csv",
      "HTTP_AUTHORIZATION" => authorization
    }
    host! "admin.acme.test"
    get "/api/v1/deliveries/#{delivery_id}/baskets.csv", headers: headers
  end

  test "requires valid api_token" do
    travel_to "2024-04-01"
    request(delivery_id: "current", api_token: "not-the-good-one")
    assert_response :unauthorized
  end

  test "returns CSV for delivery by ID" do
    travel_to "2024-04-01"
    delivery = deliveries(:monday_1)
    request(delivery_id: delivery.id)

    assert_response :success
    assert_includes response.content_type, "text/csv"
    assert_includes response.headers["Content-Disposition"], "delivery-"
  end

  test "resolves 'current' to the current delivery" do
    travel_to "2024-04-01"
    request(delivery_id: "current")

    assert_response :success
    assert_includes response.content_type, "text/csv"
  end

  test "resolves 'next' to the next upcoming delivery" do
    travel_to "2024-04-02"
    request(delivery_id: "next")

    assert_response :success
    assert_includes response.content_type, "text/csv"
  end

  test "returns 404 when delivery not found" do
    request(delivery_id: 999999)
    assert_response :not_found
  end

  test "returns 404 when no current delivery exists" do
    travel_to "2020-01-01"
    request(delivery_id: "current")
    assert_response :not_found
  end

  test "returns 404 when no next delivery exists" do
    travel_to "2030-01-01"
    request(delivery_id: "next")
    assert_response :not_found
  end
end
