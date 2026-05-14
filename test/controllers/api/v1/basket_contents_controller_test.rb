# frozen_string_literal: true

require "test_helper"

class API::V1::BasketContentsControllerTest < ActionDispatch::IntegrationTest
  def request(api_token: nil)
    api_token ||= Current.org.api_token
    authorization = ActionController::HttpAuthentication::Token.encode_credentials(api_token)
    headers = {
      "ACCEPT" => "application/json",
      "HTTP_AUTHORIZATION" => authorization
    }
    host! "admin.acme.test"
    get "/api/v1/basket_contents/current", headers: headers
  end

  test "requires valid api_token" do
    request(api_token: "not-the-good-one")
    assert_response :unauthorized
  end

  test "returns current delivery and its basket contents" do
    travel_to "2024-04-01"
    create_basket_content(
      delivery: deliveries(:monday_1),
      product: basket_content_products(:cucumbers),
      basket_size_ids_quantities: {
        medium_id => 200,
        small_id => 100
      },
      depots: [ depots(:farm), depots(:home) ],
      unit: "pc")

    request

    assert_response :success
    assert_includes response.content_type, "application/json"
    assert_equal({
      "delivery" => {
        "id" => deliveries(:monday_1).id,
        "date" => "2024-04-01"
      },
      "products" => [ {
        "id" => basket_content_products(:cucumbers).id,
        "unit" => "pc",
        "quantities" => [
          {
            "basket_size_id" => small_id,
            "quantity" => 100.0
          },
          {
            "basket_size_id" => medium_id,
            "quantity" => 200.0
          }
        ],
        "depot_ids" => [ depots(:farm).id, depots(:home).id ].sort
      } ]
    }, json_response)
  end
end
