require 'rails_helper'

describe 'Halfday Works calendar feed' do
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
      get '/halfday_works/calendar.ics', params: { auth_token: 'wrong' }
      expect(response.status).to eq 401
    end
  end

  context 'with a good auth token' do
    let!(:halfday_work) { create(:halfday_work, participants_count: 3) }

    it 'responds 200' do
      get '/halfday_works/calendar.ics', params: { auth_token: ENV['ICALENDAR_AUTH_TOKEN'] }
      expect(response.status).to eq 200
      expect(response.body).to include "#{halfday_work.member.name} (3)"
    end
  end
end
