require 'rails_helper'

describe 'Activitys RSS feed' do
  before { integration_session.host = 'membres.ragedevert.test' }

  it 'returns an RSS feed with coming and available activities' do
    create(:activity, date: Date.today + 2.days, place: 'Too Soon')
    create(:activity, date: Date.today + 3.days, place: 'Just Good')
    activity = create(:activity, date: Date.today + 1.weeks, place: 'Full', participants_limit: 1)
    create(:activity_participation, activity: activity)

    get '/activities.rss'

    expect(response.status).to eq 200
    expect(response.content_type).to eq 'application/rss+xml'
    expect(response.body).to include('Just Good')
    expect(response.body).not_to include('Too Soon')
    expect(response.body).not_to include('Full')
  end

  it 'returns an RSS feed with coming and extra dates' do
    create(:activity, date: 5.days.from_now, place: 'Good One')
    create(:activity, date: 6.days.from_now, place: 'Good Two')
    create(:activity, date: 7.days.from_now, place: 'Good Three')
    create(:activity, date: 1.month.from_now, place: 'Last One')

    get '/activities.rss?limit=2'

    expect(response.status).to eq 200
    expect(response.content_type).to eq 'application/rss+xml'
    expect(response.body).to include('Good One')
    expect(response.body).to include('Good Two')
    expect(response.body).not_to include('Good Three')
    expect(response.body).not_to include('Last One')
    expect(response.body)
      .to include("... et encore 2 autres jusqu'au #{I18n.l(1.month.from_now.to_date, format: :long)}")
  end

  it 'returns an RSS feed with empty item when no available activities' do
    get '/activities.rss'

    expect(response.status).to eq 200
    expect(response.content_type).to eq 'application/rss+xml'

    expect(response.body).to include('Aucune')
  end
end
