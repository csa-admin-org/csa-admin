require 'rails_helper'

describe 'members page' do
  before {
    Capybara.app_host = 'http://membres.ragedevert.test'
    create_deliveries(52)
  }

  it 'shows current membership info and activities count' do
    travel_to '2020-06-01' do
      member = create(:member, :active)
      create(:basket_complement, id: 1, name: 'Oeufs')
      member.current_year_membership.update!(
        activity_participations_demanded_annualy: 3,
        basket_size: create(:basket_size, name: 'Petit'),
        depot: create(:depot, name: 'Jardin de la main'),
        memberships_basket_complements_attributes: {
          '0' => { basket_complement_id: 1 }
        })

      login(member)
      visit '/deliveries'

      expect(current_path).to eq '/deliveries'
      expect(page).to have_content 'Petit'
      expect(page).to have_content 'Oeufs'
      expect(page).to have_content 'Jardin de la main'
    end
  end

  it 'redirects when no membership' do
    login(create(:member))

    visit '/deliveries'

    expect(current_path).not_to eq '/deliveries'
  end
end
