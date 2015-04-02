require 'rails_helper'

describe 'Next Delivery xlsx' do
  before do
    reset!
    integration_session.host = 'admin.example.com'
  end

  context 'without auth token' do
    it 'responds 401' do
      get '/deliveries/next'
      expect(response.status).to eq 401
    end
  end

  context 'with a wrong auth token' do
    it 'responds 401' do
      get '/deliveries/next', auth_token: 'wrong'
      expect(response.status).to eq 401
    end
  end

  context 'with a good auth token' do
    # let!(:distribution) { create(:distribution) }
    # let!(:delivery) { create(:delivery, date: 1.week.from_now) }

    it 'responds 200' do
      get '/deliveries/next',
        auth_token: ENV['DELIVERY_AUTH_TOKEN'],
        subdomain: 'admin'
      expect(response.status).to eq 200
    end
  end
end
