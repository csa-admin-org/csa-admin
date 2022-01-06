require 'rails_helper'

describe 'Shop::Order' do
  let(:member) { create(:member) }

  before do
    Capybara.app_host = 'http://membres.ragedevert.test'
    login(member)
  end

  let(:product1) {
    create(:shop_product,
      variants_attributes: {
        '0' => {
          name: '1 kg',
          price: 10,
          stock: 3
        }
      })
  }
  let(:product2) {
    create(:shop_product,
      variants_attributes: {
        '0' => {
          name: '1 kg',
          price: 5
        }
      })
  }

  specify 'no shop delivery' do
    visit '/shop'
    expect(current_path).not_to eq '/shop'
  end

  specify 'shop delivery for next delivery' do
    Current.acp.update!(
      shop_delivery_open_delay_in_days: 2,
      shop_delivery_open_last_day_end_time: Tod::TimeOfDay.parse('12:00:00'))
    create(:delivery, shop_open: true, date: '2021-11-10')
    create(:delivery, shop_open: true, date: '2021-11-17')
    create(:membership, member: member, started_on: '2021-11-12', ended_on: '2021-11-30')

    travel_to '2021-11-08 11:59 +01' do
      visit '/shop'
      expect(current_path).to eq '/shop'
      expect(page).to have_content 'Livraison du mercredi 17 novembre 2021'
      expect(page).to have_content "Votre commande peut-être passée ou modifié jusqu'au lundi 15 novembre 2021 12h00."
    end
  end

  specify 'shop delivery open/closed depending date' do
    Current.acp.update!(
      shop_delivery_open_delay_in_days: 2,
      shop_delivery_open_last_day_end_time: Tod::TimeOfDay.parse('12:00:00'))
    delivery = create(:delivery, shop_open: true, date: '2021-11-10')
    create(:delivery, shop_open: true, date: '2021-11-17')
    create(:membership, member: member, started_on: '2021-11-01', ended_on: '2021-11-30')

    travel_to '2021-11-08 11:59 +01' do
      visit '/shop'
      expect(current_path).to eq '/shop'
      expect(page).to have_content "Votre commande peut-être passée ou modifié jusqu'au lundi 08 novembre 2021 12h00."
    end
    travel_to '2021-11-08 12:01 +01' do
      visit '/shop'
      expect(current_path).to eq '/shop'
      expect(page).to have_content "Il n'est plus possible de passer commande pour cette livraison."
    end
    travel_to '2021-11-08 12:01 +01' do
      delivery = create(:delivery, shop_open: true, date: '2021-11-17')
      visit '/shop'
      expect(current_path).to eq '/shop'
      expect(page).to have_content "Il n'est plus possible de passer commande pour cette livraison."
      expect(page).to have_link "Passer commande pour la livraison du 17 novembre 2021", href: '/shop/next'
    end
  end

  specify 'add product to cart' do
    product1
    product2
    delivery = create(:delivery, shop_open: true, date: '2021-11-10')
    create(:membership, member: member, started_on: '2021-11-01', ended_on: '2021-11-30')

    travel_to '2021-11-08 08:00 +01' do
      visit '/shop'
      within("#product_variant_#{product1.variants.first.id}") do
        expect(page).to have_content "3 disponibles"
        click_button 'Ajouter au panier'
        expect(page).to have_content "2 disponibles"
        click_button 'Ajouter au panier'
        expect(page).to have_content "1 disponible"
        click_button 'Ajouter au panier'
        expect(page).to have_content "0 disponible"
        expect(page).not_to have_button('Ajouter au panier')
      end
      within("#product_variant_#{product2.variants.first.id}") do
        click_button 'Ajouter au panier'
      end

      within('#cart') do
        expect(page).to have_content "4 Produits\nCHF 35.00"
      end
    end

    order = member.shop_orders.last
    expect(order.items.sum(:quantity)).to eq 4
    expect(order.amount).to eq 35
  end
end
