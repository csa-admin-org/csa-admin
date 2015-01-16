require 'rails_helper'

describe 'Gribouille Emails list' do
  before do
    reset!
    integration_session.host = 'admin.example.com'
  end

  context 'without auth token' do
    it 'responds 401' do
      get '/gribouille_emails'
      expect(response.status).to eq 401
    end
  end

  context 'with a wrong auth token' do
    it 'responds 401' do
      get '/gribouille_emails', auth_token: 'wrong'
      expect(response.status).to eq 401
    end
  end

  context 'with a good auth token' do
    let!(:member) { create(:member, gribouille: true, emails: 'foo@foo.com') }

    it 'responds 200' do
      get '/gribouille_emails',
        auth_token: ENV['GRIBOUILLE_AUTH_TOKEN'],
        subdomain: 'admin'
      expect(response.status).to eq 200
      expect(response.body).to include "#{member.emails}"
    end
  end
end
