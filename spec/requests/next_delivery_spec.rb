require 'rails_helper'

describe 'Next Delivery xlsx' do
  before { integration_session.host = 'admin.ragedevert.test' }

  context 'without auth token' do
    it 'responds 401' do
      get '/deliveries/next'
      expect(response.status).to eq 401
    end
  end

  context 'with a wrong auth token' do
    it 'responds 401' do
      get '/deliveries/next', params: { auth_token: 'wrong' }
      expect(response.status).to eq 401
    end
  end

  context 'with a good auth token' do
    let!(:distribution) { create(:distribution, id: 2) }
    let!(:delivery) { create(:delivery, date: 1.week.from_now) }

    it 'responds 200' do
      get '/deliveries/next', params: { auth_token: ENV['DELIVERY_AUTH_TOKEN'] }
      expect(response.status).to eq 200
    end
  end
end
