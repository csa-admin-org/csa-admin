require 'rails_helper'

describe Liquid::DataPreview do
  specify 'recursively render drop data', freeze: '2020-01-01' do
    create(:delivery, date: '2020-01-07')
    create(:delivery, date: '2020-10-06')
    create(:depot, id: 12, name: 'Jardin de la main')
    create(:basket_size, id: 33, name: 'Eveil')

    mail_template = MailTemplate.find_by(title: 'member_activated')
    data =  described_class.for(mail_template, random: 1)

    expect(data).to eq({
      'acp' => {
        'activity_phone' => '+41 77 447 26 16',
        'email' => 'info@ragedevert.ch',
        'name'=> 'Rage de Vert',
        'phone'=> '+41 77 447 26 16',
        'url' => 'https://www.ragedevert.ch'
      },
      'member' =>  {
        'name' => 'John Doe',
        'billing_email' => false,
        'page_url' => 'https://membres.ragedevert.ch',
        'billing_url' => 'https://membres.ragedevert.ch/billing',
        'activities_url' => 'https://membres.ragedevert.ch/activity_participations',
        'membership_renewal_url' => 'https://membres.ragedevert.ch/membership#renewal'
      },
      'membership' => {
        'activity_participations_demanded_count' => 2,
        'basket_complement_names' => nil,
        'basket_complements' => [],
        'basket_size' => {
          'id' => 33,
          'name' => 'Eveil PUBLIC'
        },
        'depot' => {
          'id' => 12,
          'name' => 'Jardin de la main PUBLIC'
        },
        'end_date' => '31 décembre 2020',
        'start_date' => '1 janvier 2020',
        'first_delivery' => {
          'date' => '7 janvier 2020'
        },
        'last_delivery' => {
          'date' => '6 octobre 2020'
        },
        'trial_baskets_count' => 4
      }
    })
  end

  specify 'render non-drop data' do
    basket_size = create(:basket_size)
    depot = create(:depot)
    data = travel_to('2020-03-24') do
      mail_template = MailTemplate.find_by(title: 'member_validated')
      described_class.for(mail_template, random: 1)
    end

    expect(data).to eq({
      'acp' => {
        'activity_phone' => '+41 77 447 26 16',
        'email' => 'info@ragedevert.ch',
        'name'=> 'Rage de Vert',
        'phone'=> '+41 77 447 26 16',
        'url' => 'https://www.ragedevert.ch'
      },
      'member' =>  {
        'name' => 'John Doe',
        'billing_email' => false,
        'page_url' => 'https://membres.ragedevert.ch',
        'billing_url' => 'https://membres.ragedevert.ch/billing',
        'activities_url' => 'https://membres.ragedevert.ch/activity_participations',
        'membership_renewal_url' => 'https://membres.ragedevert.ch/membership#renewal'
      },
      'waiting_list_position' => 1,
      'waiting_basket_size_id' => basket_size.id,
      'waiting_depot_id' => depot.id
    })
  end

  specify 'without activity feature', freeze: '2020-01-01' do
    Current.acp.update!(features: [])
    create(:delivery, date: '2020-01-07')
    create(:delivery, date: '2020-10-06')
    create(:depot, id: 12, name: 'Jardin de la main')
    create(:basket_size, id: 33, name: 'Eveil')

    mail_template = MailTemplate.find_by(title: 'member_activated')
    data = described_class.for(mail_template, random: 1)

    expect(data).to eq({
      'acp' => {
        'email' => 'info@ragedevert.ch',
        'name'=> 'Rage de Vert',
        'phone'=> '+41 77 447 26 16',
        'url' => 'https://www.ragedevert.ch'
      },
      'member' =>  {
        'name' => 'John Doe',
        'billing_email' => false,
        'page_url' => 'https://membres.ragedevert.ch',
        'billing_url' => 'https://membres.ragedevert.ch/billing',
        'membership_renewal_url' => 'https://membres.ragedevert.ch/membership#renewal'
      },
      'membership' => {
        'basket_complement_names' => nil,
        'basket_complements' => [],
        'basket_size' => {
          'id' => 33,
          'name' => 'Eveil PUBLIC'
        },
        'depot' => {
          'id' => 12,
          'name' => 'Jardin de la main PUBLIC'
        },
        'end_date' => '31 décembre 2020',
        'start_date' => '1 janvier 2020',
        'first_delivery' => {
          'date' => '7 janvier 2020'
        },
        'last_delivery' => {
          'date' => '6 octobre 2020'
        },
        'trial_baskets_count' => 4
      }
    })
  end
end
