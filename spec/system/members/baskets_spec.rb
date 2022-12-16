require 'rails_helper'

describe 'Baskets' do
  let(:member) { create(:member) }

  before do
    Capybara.app_host = 'http://membres.ragedevert.test'
  end

  specify 'update depot', freeze: '2022-01-01' do
    Current.acp.update!(membership_depot_update_allowed: true)

    depot_1 = create(:depot, public_name: 'Joli Lieu')
    depot_2 = create(:depot, public_name: 'Beau Lieu')

    create(:delivery, date: '2022-02-01')
    membership = create(:membership, member: member, depot: depot_1)
    basket = member.current_year_membership.baskets.first

    login(member)
    expect(menu_nav).to include "Livraisons\n⤷ 1 février 2022"
    click_on 'Livraisons'

    expect(current_path).to eq '/deliveries'
    expect(page).to have_content 'Joli Lieu'

    click_on 'Modifier'
    choose 'Beau Lieu'

    expect {
      click_on 'Confirmer'
    }.to change { basket.reload.depot }.from(depot_1).to(depot_2)

    expect(current_path).to eq '/deliveries'
    expect(page).to have_content 'Beau Lieu'
  end

  specify 'update depot not allowed', freeze: '2022-01-01' do
    create(:delivery, date: '2022-02-01')
    membership = create(:membership, member: member)

    login(member)
    expect(menu_nav).to include "Livraisons\n⤷ 1 février 2022"
    click_on 'Livraisons'

    expect(current_path).to eq '/deliveries'
    expect(page).not_to have_link 'Modifier'
  end
end
