# frozen_string_literal: true

require "rails_helper"

describe "BasketContents V1 API" do
  before { integration_session.host = "admin.acme.test" }

  describe "GET /api/v1/basket_contents/current" do
    def request(api_token: nil)
      api_token ||= Current.org.credentials(:api_token)
      authorization =
        ActionController::HttpAuthentication::Token.encode_credentials(api_token)
      headers = {
        "ACCEPT" => "application/json",
        "HTTP_AUTHORIZATION" => authorization
      }
      get "/api/v1/basket_contents/current", headers: headers
    end

    it "requires valid api_token" do
      request(api_token: "not-the-good-one")
      expect(response.status).to eq 401
    end

    it "returns current delivery and its basket contents" do
      small_basket = create(:basket_size, :small, id: 125123)
      big_basket = create(:basket_size, :big, id: 623411)
      depot1 = create(:depot, id: 161412)
      depot2 = create(:depot, id: 645231)

      delivery = travel_to "2021-06-01" do
        create(:delivery, id: 526123, date: "2021-06-18")
      end
      travel_to "2021-06-01" do
        create(:membership, depot: depot1, basket_size: small_basket)
        create(:membership, depot: depot1, basket_size: big_basket)
        create(:membership, depot: depot2, basket_size: big_basket)
      end

      travel_to "2021-06-18 04:12:00" do
        create(:basket_content,
          product: create(:product, id: 734521),
          delivery: delivery,
          depot_ids: [ depot1.id, depot2.id ],
          basket_size_ids_percentages: { big_basket.id => 100 },
          quantity: 10,
          unit: "pc")
        create(:basket_content,
          product: create(:product, id: 643241),
          delivery: delivery,
          basket_size_ids_percentages: {
            small_basket.id => 41,
            big_basket.id => 59
          },
          basket_size_ids: [ small_basket.id, big_basket.id ],
          depot_ids: [ depot1.id ],
          quantity: 5,
          unit: "kg")

        request
      end

      expect(response.status).to eq 200
      expect(response.headers).to match(hash_including(
        "etag" => "W/\"bdf3e5fcbb93bca3c3ce2346c78e855f\"",
        "last-modified" => "Fri, 18 Jun 2021 02:12:00 GMT"
      ))
      expect(JSON(response.body)).to eq(
        "delivery" => {
          "id" => 526123,
          "date" => "2021-06-18"
        },
        "products" => [
          {
            "id" => 734521,
            "unit" => "pc",
            "quantities" => [
              {
                "basket_size_id" => 623411,
                "quantity" => 5
              }
            ],
            "depot_ids" => [ 161412, 645231 ]
          },
          {
            "id" => 643241,
            "unit" => "kg",
            "quantities" =>  [
              {
                "basket_size_id" => 125123,
                "quantity" => 2.049
              },
             {
               "basket_size_id" => 623411,
               "quantity" => 2.951
              }
            ],
            "depot_ids" => [ 161412 ]
          }
        ])
    end
  end
end
