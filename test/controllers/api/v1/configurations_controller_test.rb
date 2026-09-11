# frozen_string_literal: true

require "test_helper"

class API::V1::ConfigurationsControllerTest < ActionDispatch::IntegrationTest
  def request(api_token: nil)
    api_token ||= Current.org.api_token
    authorization = ActionController::HttpAuthentication::Token.encode_credentials(api_token)
    headers = {
      "ACCEPT" => "application/json",
      "AUTHORIZATION" => authorization
    }
    host! "admin.acme.test"
    get "/api/v1/configuration", headers: headers
  end

  test "requires valid api_token" do
    request(api_token: "not-the-good-one")
    assert_response :unauthorized
  end

  test "returns basket sizes, depots, and basket_content_products" do
    travel_to "2021-06-17" do
      request
    end

    assert_response :success
    assert_includes response.content_type, "application/json"
    assert_equal({
      "basket_sizes" => [
        { "id" => small_id, "visible" => true, "names" => { "en" => "Small basket" } },
        { "id" => medium_id, "visible" => true, "names" => { "en" => "Medium basket" } },
        { "id" => basket_sizes(:large).id, "visible" => true, "names" => { "en" => "Large basket" } }
      ],
      "depots" => [
        { "id" => depots(:bakery).id, "visible" => true, "names" => { "en" => "Bakery" } },
        { "id" => depots(:farm).id, "visible" => true, "names" => { "en" => "Our farm" } },
        { "id" => home_id, "visible" => true, "names" => { "en" => "Home" } }
      ],
      "basket_content_products" => [
        { "id" => basket_content_products(:carrots).id, "names" => { "en" => "Carrots" } },
        { "id" => basket_content_products(:cucumbers).id, "names" => { "en" => "Cucumbers" } }
      ]
    }, json_response)
  end
end
