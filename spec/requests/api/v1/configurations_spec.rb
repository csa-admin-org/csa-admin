require "rails_helper"

describe "Configurations V1 API" do
  before { integration_session.host = "admin.ragedevert.test" }

  describe "/api/v1/configuration" do
    def request(api_token: nil)
      api_token ||= Current.acp.credentials(:api_token)
      authorization =
        ActionController::HttpAuthentication::Token.encode_credentials(api_token)
      headers = {
        "ACCEPT" => "application/json",
        "HTTP_AUTHORIZATION" => authorization
      }
      get "/api/v1/configuration", headers: headers
    end

    it "requires valid api_token" do
      request(api_token: "not-the-good-one")
      expect(response.status).to eq 401
    end

    it "returns basket sizes, depots, and basket_content_products" do
      travel_to "2021-06-17" do
        create(:depot, name: "Vieux Dépôt")
        depot = create(:depot, id: 1324124, name: "Dépôt A", public_name: "")
        basket_size = create(:basket_size, id: 435132, name: "Grand", public_name: "Grand P")
        create(:membership, depot: depot, basket_size: basket_size)
        create(:product, id: 5234123, name: "Carotte")
      end
      travel_to "2021-06-18 04:12:00" do
        create(:product, id: 4354234, name: "Chou")
      end

      travel_to "2021-06-19" do
        request
      end

      expect(response.status).to eq 200
      expect(response.headers).to match(hash_including(
        "ETag" => "W/\"7cafb05d424d24860504619da110895c\"",
        "Last-Modified" => "Fri, 18 Jun 2021 02:12:00 GMT"
      ))
      expect(JSON(response.body)).to eq(
        "basket_sizes" => [
          {
            "id" => 435132,
            "visible" => true,
            "names" => { "fr" => "Grand P" }
          }
        ],
        "depots" => [
          {
            "id" => 1324124,
            "visible" => true,
            "names" => { "fr" => "Dépôt A" }
          }
        ],
        "basket_content_products" => [
          {
            "id" => 5234123,
            "names" => { "fr" => "Carotte" }
          },
          {
            "id" => 4354234,
            "names" => { "fr" => "Chou" }
          }
        ])
    end
  end
end
