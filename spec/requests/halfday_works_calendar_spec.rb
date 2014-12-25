require 'rails_helper'

describe 'Halfday Works calendar feed' do
  fixtures :halfday_works

  before do
    reset!
    integration_session.host = 'admin.example.com'
  end

  context 'without auth token' do
    it 'responds 401' do
      get '/halfday_works/calendar.ics'
      expect(response.status).to eq 401
    end
  end

  context 'with a wrong auth token' do
    it 'responds 401' do
      get '/halfday_works/calendar.ics', auth_token: 'wrong'
      expect(response.status).to eq 401
    end
  end

  context 'with a good auth token' do
    it 'responds 200' do
      get '/halfday_works/calendar.ics', auth_token: ENV['ICALENDAR_AUTH_TOKEN'], subdomain: 'admin'
      expect(response.status).to eq 200
      expect(response.body).to include 'John Doe'
      expect(response.body).to include 'John Doe (2)'
    end
  end

end
