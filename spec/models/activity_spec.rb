require 'rails_helper'

describe Activity do
  it_behaves_like 'bulk_dates_insert'

  it 'validates title presence' do
    activity = Activity.new(title_fr: '')
    expect(activity).not_to have_valid(:title_fr)
  end

  it 'validates participants_limit to be at least 1' do
    activity = Activity.new(participants_limit: 0)
    expect(activity).not_to have_valid(:participants_limit)

    activity = Activity.new(participants_limit: nil)
    expect(activity).to have_valid(:participants_limit)
  end

  it 'validates that end_time is greather than start_time' do
    activity = Activity.new(start_time: '11:00', end_time: '10:00')
    expect(activity).not_to have_valid(:end_time)
  end

  it 'validates that period is one hour when activity_i18n_scope is hour_work' do
    current_acp.update!(activity_i18n_scope: 'hour_work')

    activity = Activity.new(start_time: '10:00', end_time: '11:01')
    expect(activity).not_to have_valid(:end_time)
  end

  it 'creates an activity without preset' do
    activity = Activity.new(
      date: '2018-03-24',
      start_time: '8:30',
      end_time: '12:00',
      place: 'Thielle',
      place_url: 'https://goo.gl/maps/xSxmiYRhKWH2',
      title: 'Aide aux champs',
      participants_limit: 3,
      description: 'Venez nombreux!')

    expect(activity.preset_id).to be_nil
    expect(activity.places['fr']).to eq 'Thielle'

    activity.save!

    expect(activity.start_time).to eq Tod::TimeOfDay.parse('8:30')
    expect(activity.end_time).to eq Tod::TimeOfDay.parse('12:00')
  end

  it 'creates an activity with preset' do
    preset = ActivityPreset.create!(
      place: 'Thielle',
      place_url: 'https://goo.gl/maps/xSxmiYRhKWH2',
      title: 'Aide aux champs')
    activity = Activity.new(
      date: '2018-03-24',
      start_time: '8:30',
      end_time: '12:00',
      preset_id: preset.id)

    expect(activity.preset_id).to be_present
    expect(activity.places['fr']).to eq 'preset'
    expect(activity.place_urls['de']).to eq 'preset'
    expect(activity.titles['xx']).to eq 'preset'

    activity.save!

    h = Activity.find(activity.id)
    expect(h.place).to eq 'Thielle'
    expect(h.place_url).to eq 'https://goo.gl/maps/xSxmiYRhKWH2'
    expect(h.title).to eq  'Aide aux champs'
  end

  describe '#period' do
    it 'does not pad hours' do
      activity = Activity.new(
        date: '2018-03-24',
        start_time: '8:30',
        end_time: '12:00')

      expect(activity.period).to eq '8:30-12:00'
    end
  end
end
