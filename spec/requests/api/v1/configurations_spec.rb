require 'rails_helper'

describe 'Configurations V1 API' do
  before { integration_session.host = 'admin.ragedevert.test' }

  describe '/api/v1/configuration' do
    def request(api_token: nil)
      api_token ||= Current.acp.credentials(:api_token)
      authorization =
        ActionController::HttpAuthentication::Token.encode_credentials(api_token)
      headers = {
        'ACCEPT' => 'application/json',
        'HTTP_AUTHORIZATION' => authorization
      }
      get '/api/v1/configuration', headers: headers
    end

    it 'requires valid api_token' do
      request(api_token: 'not-the-good-one')
      expect(response.status).to eq 401
    end

    it 'returns basket sizes, depots, and vegetables' do
      travel_to '2021-06-17' do
        create(:depot, id: 1324124, name: 'Dépôt A', form_name: '')
        create(:basket_size, id: 435132, name: 'Grand')
        create(:vegetable, id: 5234123, name: 'Carotte')
      end
      travel_to '2021-06-18 04:12:00' do
        create(:vegetable, id: 4354234, name: 'Chou')
      end

      request

      expect(response.status).to eq 200
      expect(response.headers).to match(hash_including(
        "ETag" => "W/\"15999dbf582b394f501abae3d09e4732\"",
        "Last-Modified" => "Fri, 18 Jun 2021 02:12:00 GMT"
      ))
      expect(JSON(response.body)).to eq(
        'basket_sizes' => [
          {
            'id' => 435132,
            'names' => { 'fr' => 'Grand' }
          }
        ],
        'depots' => [
          {
            'id' => 1324124,
            'names' => { 'fr' => 'Dépôt A' }
          }
        ],
        'vegetables' => [
          {
            'id' => 5234123,
            'names' => { 'fr' => 'Carotte' }
          },
          {
            'id' => 4354234,
            'names' => { 'fr' => 'Chou' }
          }
        ])
    end
  end
end
