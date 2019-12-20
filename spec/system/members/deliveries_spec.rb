require 'rails_helper'

describe 'members page' do
  before {
    Capybara.app_host = 'http://membres.ragedevert.test'
    create_deliveries(52)
  }

  it 'shows current membership info and activities count' do
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

    expect(page).to have_content 'Panier: Petit'
    expect(page).to have_content 'Complément: Oeufs'
    expect(page).to have_content 'Dépôt: Jardin de la main'
  end

  it 'shows no membership text' do
    login(create(:member))

    visit '/deliveries'

    expect(page).to have_content 'Aucun abonnement'
  end
end
