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

  specify 'update basket complements', freeze: '2022-01-01' do
    Current.acp.update!(membership_complements_update_allowed: true)

    create(:delivery, date: '2022-02-01')
    membership = create(:membership, member: member)
    basket = member.current_year_membership.baskets.first

    oeufs = create(:basket_complement, public_name: 'Oeufs', visible: false, price: 1.1)
    tofu = create(:basket_complement, public_name: 'Tofu', price: 2.2)
    pain = create(:basket_complement, public_name: 'Pain', price: 3.3)
    create(:basket_complement, public_name: 'Fromage', visible: false)
    create(:basket_complement, public_name: 'Pommes', delivery_ids: [])

    basket.baskets_basket_complements.create!(basket_complement: oeufs, quantity: 2)
    basket.baskets_basket_complements.create!(basket_complement: tofu, quantity: 1)

    login(member)
    expect(menu_nav).to include "Livraisons\n⤷ 1 février 2022"
    click_on 'Livraisons'

    expect(current_path).to eq '/deliveries'
    expect(page).to have_content '2x Oeufs et Tofu'

    click_on 'Modifier'

    expect(page).not_to have_content 'Fromage'
    expect(page).not_to have_content 'Pommes'

    fill_in 'Oeufs', with: '0'
    fill_in 'Tofu', with: '3'
    fill_in 'Pain', with: '1'

    expect {
      expect { click_on 'Confirmer' }
        .to change { basket.reload.complements.map(&:id) }
        .from([oeufs.id, tofu.id]).to([tofu.id, pain.id])
    }.to change { membership.reload.basket_complements_price }.from(4.4).to(9.9)

    expect(current_path).to eq '/deliveries'
    expect(page).to have_content 'Pain et 3x Tofu'
  end

  specify 'update not allowed', freeze: '2022-01-01' do
    create(:delivery, date: '2022-02-01')
    membership = create(:membership, member: member)

    login(member)
    expect(menu_nav).to include "Livraisons\n⤷ 1 février 2022"
    click_on 'Livraisons'

    expect(current_path).to eq '/deliveries'
    expect(page).not_to have_link 'Modifier'
  end
end
