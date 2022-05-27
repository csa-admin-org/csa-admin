require 'rails_helper'

describe 'Shop::Order' do
  let(:member) { create(:member, id: 110128) }

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

  specify 'increase order item with input' do
    travel_to '2021-11-08' do
      delivery = create(:delivery, shop_open: true, date: '2021-11-10')
      create(:membership, member: member, started_on: '2021-11-01', ended_on: '2021-11-30')
      order = create(:shop_order, :cart,
        member: member,
        delivery: delivery,
        items_attributes: {
          '0' => {
            product_id: product1.id,
            product_variant_id: product1.variants.first.id,
            quantity: 1
          },
          '1' => {
            product_id: product2.id,
            product_variant_id: product2.variants.first.id,
            quantity: 1
          }
        })

      visit "/shop/orders/#{order.id}"
      expect(current_path).to eq "/shop/orders/#{order.id}"

      fill_in "shop_order_items_attributes_0_quantity", with: 4
      find('input[aria-label="update_order"]', visible: false).click
      expect(page).to have_content('doit être inférieur ou égal à 3')

      fill_in "shop_order_items_attributes_0_quantity", with: 3
      find('input[aria-label="update_order"]', visible: false).click

      expect(order.reload.items.pluck(:product_id, :quantity))
        .to contain_exactly([product1.id, 3], [product2.id, 1])
    end
  end

  specify 'remove a cart order item' do
    travel_to '2021-11-08' do
      delivery = create(:delivery, shop_open: true, date: '2021-11-10')
      create(:membership, member: member, started_on: '2021-11-01', ended_on: '2021-11-30')
      order = create(:shop_order, :cart,
        delivery: Delivery.last,
        member: member,
        items_attributes: {
          '0' => {
            product_id: product1.id,
            product_variant_id: product1.variants.first.id,
            quantity: 1
          },
          '1' => {
            product_id: product2.id,
            product_variant_id: product2.variants.first.id,
            quantity: 1
          }
        })

      visit "/shop/orders/#{order.id}"
      expect(current_path).to eq "/shop/orders/#{order.id}"

      fill_in "shop_order_items_attributes_0_quantity", with: 3
      fill_in "shop_order_items_attributes_1_quantity", with: 0
      find('input[aria-label="update_order"]', visible: false).click

      expect(order.reload.items.pluck(:product_id, :quantity))
        .to eq([[product1.id, 3]])
    end
  end

  specify 'unavailable product in cart order' do
    travel_to '2021-11-08' do
      delivery = create(:delivery, shop_open: true, date: '2021-11-10')
      create(:membership, member: member, started_on: '2021-11-01', ended_on: '2021-11-30')
      order = create(:shop_order, :cart,
        delivery: Delivery.last,
        member: member,
        items_attributes: {
          '0' => {
            product_id: product1.id,
            product_variant_id: product1.variants.first.id,
            quantity: 1
          },
          '1' => {
            product_id: product2.id,
            product_variant_id: product2.variants.first.id,
            quantity: 1
          }
        })

      product1.update!(available: false)

      visit "/shop/orders/#{order.id}"
      expect(current_path).to eq "/shop/orders/#{order.id}"

      within 'label[for="shop_order_items_attributes_0_quantity"]' do
        expect(page).to have_content('indisponible')
      end

      button = find('button[aria-label="confirm_order"]')
      expect(button).to be_disabled
    end
  end

  specify 'cart can be finalize depending date' do
    order = nil
    travel_to '2021-11-08 11:59 +01' do
      Current.acp.update!(
        shop_delivery_open_delay_in_days: 2,
        shop_delivery_open_last_day_end_time: Tod::TimeOfDay.parse('12:00:00'))
      delivery = create(:delivery, shop_open: true, date: '2021-11-10')
      create(:membership, member: member, started_on: '2021-11-01', ended_on: '2021-11-30')
      order = create(:shop_order, :cart,
        member: member,
        delivery: delivery,
        items_attributes: {
          '0' => {
            product_id: product1.id,
            product_variant_id: product1.variants.first.id,
            quantity: 1
          }
        })

      visit "/shop/orders/#{order.id}"
      expect(current_path).to eq "/shop/orders/#{order.id}"
      expect(page).to have_content "Votre commande peut-être passée ou modifié jusqu'au lundi 08 novembre 2021 12h00."
      expect(page).to have_button('Commander')
    end
    travel_to '2021-11-08 12:01 +01' do
      visit "/shop/orders/#{order.id}"
      expect(current_path).to eq '/shop'
      expect(page).to have_content "Il n'est plus possible de passer commande pour cette livraison."
    end
  end

  specify 'pending order can be modified/deleted depending date' do
    order = nil
    travel_to '2021-11-08 11:59 +01' do
      Current.acp.update!(
        shop_delivery_open_delay_in_days: 2,
        shop_delivery_open_last_day_end_time: Tod::TimeOfDay.parse('12:00:00'))
      delivery = create(:delivery, shop_open: true, date: '2021-11-10')
      create(:membership, member: member, started_on: '2021-11-01', ended_on: '2021-11-30')
      order = create(:shop_order, :pending,
        member: member,
        delivery: delivery,
        items_attributes: {
          '0' => {
            product_id: product1.id,
            product_variant_id: product1.variants.first.id,
            quantity: 1
          }
        })

      visit "/shop/orders/#{order.id}"
      expect(current_path).to eq "/shop/orders/#{order.id}"
      expect(page).to have_content "Votre commande a bien été reçue mais peut encore être annulée ou modifiée jusqu'au lundi 08 novembre 2021 12h00. Une facture vous sera envoyée ultérieurement, avant la livraison, par email. Merci de la régler rapidement."
      expect(page).to have_button('Modifier')
      expect(page).to have_button('Annuler la commande')
    end
    travel_to '2021-11-08 12:01 +01' do
      visit "/shop/orders/#{order.id}"
      expect(current_path).to eq "/shop/orders/#{order.id}"
      expect(page).to have_content "Votre commande est entrain d'être préparée, une facture vous sera bientôt envoyée par email. Merci de la régler rapidement."
      expect(page).not_to have_button('Modifier')
      expect(page).not_to have_button('Annuler la commande')
    end
  end

  specify 'invoiced order' do
    travel_to '2021-11-08 12:01 +01' do
      Current.acp.update!(
        shop_delivery_open_delay_in_days: 2,
        shop_delivery_open_last_day_end_time: Tod::TimeOfDay.parse('12:00:00'))
      delivery = create(:delivery, shop_open: true, date: '2021-11-10')
      create(:membership, member: member, started_on: '2021-11-01', ended_on: '2021-11-30')
      order = create(:shop_order, :pending,
        member: member,
        delivery: delivery,
        items_attributes: {
          '0' => {
            product_id: product1.id,
            product_variant_id: product1.variants.first.id,
            quantity: 1
          }
        })
      order.invoice!

      visit "/shop/orders/#{order.id}"
      expect(current_path).to eq "/shop/orders/#{order.id}"
      expect(page).to have_content "Votre commande est prête, la facture vous a été envoyée par email. Merci de la régler rapidement."
      expect(page).to have_link("Facture ##{order.invoice.id}")
      expect(page).to have_content "Une question? N'hésitez pas à nous contacter."
    end
  end
end
