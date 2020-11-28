require 'rails_helper'

describe Liquid::DataPreview do
  specify 'recursively render drop data' do
    create(:depot, id: 12, name: 'Jardin de la main')
    create(:basket_size, id: 33, name: 'Eveil')

    data = travel_to('2020-03-24') do
      mail_template = MailTemplate.create!(title: 'member_activated')
      described_class.for(mail_template)
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
        'page_url' => 'https://membres.ragedevert.ch',
        'billing_url' => 'https://membres.ragedevert.ch/billing',
        'activities_url' => 'https://membres.ragedevert.ch/activities',
        'membership_renewal_url' => 'https://membres.ragedevert.ch/membership#renewal'
      },
      'membership' => {
        'activity_participations_demanded_count' => 2,
        'basket_complement_names' => nil,
        'basket_complements' => [],
        'basket_size' => {
          'id' => 33,
          'name' => 'Eveil'
        },
        'depot' => {
          'id' => 12,
          'name' => 'Jardin de la main'
        },
        'end_date' => '31 décembre 2020',
        'start_date' => '24 mars 2020',
        'first_delivery' => {
          'date' => '24 mars 2020'
        },
        'last_delivery' => {
          'date' => '6 octobre 2020'
        },
        'trial_baskets_count' => 4
      }
    })
  end

  specify 'render non-drop data' do
    data = travel_to('2020-03-24') do
      mail_template = MailTemplate.create!(title: 'member_validated')
      described_class.for(mail_template)
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
        'page_url' => 'https://membres.ragedevert.ch',
        'billing_url' => 'https://membres.ragedevert.ch/billing',
        'activities_url' => 'https://membres.ragedevert.ch/activities',
        'membership_renewal_url' => 'https://membres.ragedevert.ch/membership#renewal'
      },
      'waiting_list_position' => 1
    })
  end

  specify 'without activity feature' do
    Current.acp.update!(features: [])
    create(:depot, id: 12, name: 'Jardin de la main')
    create(:basket_size, id: 33, name: 'Eveil')

    data = travel_to('2020-03-24') do
      mail_template = MailTemplate.create!(title: 'member_activated')
      described_class.for(mail_template)
    end

    expect(data).to eq({
      'acp' => {
        'email' => 'info@ragedevert.ch',
        'name'=> 'Rage de Vert',
        'phone'=> '+41 77 447 26 16',
        'url' => 'https://www.ragedevert.ch'
      },
      'member' =>  {
        'name' => 'John Doe',
        'page_url' => 'https://membres.ragedevert.ch',
        'billing_url' => 'https://membres.ragedevert.ch/billing',
        'membership_renewal_url' => 'https://membres.ragedevert.ch/membership#renewal'
      },
      'membership' => {
        'basket_complement_names' => nil,
        'basket_complements' => [],
        'basket_size' => {
          'id' => 33,
          'name' => 'Eveil'
        },
        'depot' => {
          'id' => 12,
          'name' => 'Jardin de la main'
        },
        'end_date' => '31 décembre 2020',
        'start_date' => '24 mars 2020',
        'first_delivery' => {
          'date' => '24 mars 2020'
        },
        'last_delivery' => {
          'date' => '6 octobre 2020'
        },
        'trial_baskets_count' => 4
      }
    })
  end
end
