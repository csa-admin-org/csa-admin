require 'rails_helper'

describe 'Halfdays RSS feed' do
  before { integration_session.host = 'membres.ragedevert.test' }

  it 'returns an RSS feed with coming and available halfdays' do
    create(:halfday, date: Date.today + 2.days, place: 'Too Soon')
    create(:halfday, date: Date.today + 3.days, place: 'Just Good')
    halfday = create(:halfday, date: Date.today + 1.weeks, place: 'Full', participants_limit: 1)
    create(:halfday_participation, halfday: halfday)

    get '/halfdays.rss'

    expect(response.status).to eq 200
    expect(response.content_type).to eq 'application/rss+xml'
    expect(response.body).to include('Just Good')
    expect(response.body).not_to include('Too Soon')
    expect(response.body).not_to include('Full')
  end

  it 'returns an RSS feed with empty item when no available halfdays' do
    get '/halfdays.rss'

    expect(response.status).to eq 200
    expect(response.content_type).to eq 'application/rss+xml'

    expect(response.body).to include('Aucune')
  end
end
