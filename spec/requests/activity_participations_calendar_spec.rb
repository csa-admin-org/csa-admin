require 'rails_helper'

describe 'Activity Particiations calendar feed' do
  before { integration_session.host = 'admin.ragedevert.test' }

  context 'without auth token' do
    it 'responds 401' do
      get '/activity_participations/calendar.ics'
      expect(response.status).to eq 401
    end
  end

  context 'with a wrong auth token' do
    it 'responds 401' do
      get '/activity_participations/calendar.ics', params: { auth_token: 'wrong' }
      expect(response.status).to eq 401
    end
  end

  context 'with a good auth token' do
    let!(:activity_participation) { create(:activity_participation, participants_count: 3) }

    it 'responds 200' do
      auth_token = Current.acp.credentials(:icalendar_auth_token)

      get '/activity_participations/calendar.ics', params: { auth_token: auth_token }
      expect(response.status).to eq 200
      expect(response.body).to include "#{activity_participation.member.name} (3)"
    end
  end
end
