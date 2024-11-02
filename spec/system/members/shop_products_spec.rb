# frozen_string_literal: true

require "rails_helper"

describe "Shop::Order" do
  let(:member) { create(:member) }

  before do
    Current.org.update!(shop_admin_only: false)
    Capybara.app_host = "http://membres.acme.test"
    login(member)
  end

  specify "shop delivery for next delivery" do
    Current.org.update!(
      shop_delivery_open_delay_in_days: 2,
      shop_delivery_open_last_day_end_time: Tod::TimeOfDay.parse("12:00:00"))
    travel_to "2021-11-01" do
      create(:delivery, shop_open: true, date: "2021-11-10")
      create(:delivery, shop_open: true, date: "2021-11-17")
      create(:membership, member: member, started_on: "2021-11-12", ended_on: "2021-11-30")
    end

    travel_to "2021-11-08 11:59 +01" do
      visit "/shop"
      expect(current_path).to eq "/shop"
      expect(page).to have_content "Livraison du mercredi 17 novembre 2021"
      expect(page).to have_content "Votre commande peut-être passée ou modifié jusqu'au lundi 15 novembre 2021, 12:00."
    end
  end

  specify "shop delivery for next delivery of member with a shop depot", freeze: "2023-05-01" do
    create(:delivery, shop_open: true, date: "2023-06-15")
    depot = create(:depot, id: 1)
    create(:depot, id: 2)
    create(:delivery, shop_open: true, shop_open_for_depot_ids: [ 2 ], date: "2023-06-14")
    member.update!(shop_depot: depot)
    member.activate!

    visit "/shop"
    expect(current_path).to eq "/shop"
    expect(page).to have_content "Livraison du jeudi 15 juin 2023"
  end

  specify "shop delivery for next delivery of member with a shop depot (match depot / cycle)", freeze: "2023-05-01" do
    depot1 = create(:depot, id: 1)
    depot2 = create(:depot, id: 2)
    create(:delivery,
      date: "2023-06-14", # Wednesday
      shop_open: true,
      shop_open_for_depot_ids: [ 1, 2 ])
    create(:delivery,
      date: "2023-06-15", # Thursday
      shop_open: true,
      shop_open_for_depot_ids: [ 1, 2 ])
    DeliveryCycle.delete_all
    create(:delivery_cycle, depots: [ depot1 ], wdays: [ 3 ])
    create(:delivery_cycle, depots: [ depot2 ], wdays: [ 4 ])

    member.update!(shop_depot: depot2)
    member.activate!

    visit "/shop"
    expect(current_path).to eq "/shop"
    expect(page).to have_content "Livraison du jeudi 15 juin 2023"
  end

  specify "shop delivery open/closed depending date" do
    Current.org.update!(
      shop_delivery_open_delay_in_days: 2,
      shop_delivery_open_last_day_end_time: Tod::TimeOfDay.parse("12:00:00"))

    travel_to "2021-01-01" do
      create(:delivery, shop_open: true, date: "2021-11-10")
      create(:delivery, shop_open: true, date: "2021-11-17")
      create(:membership, member: member, started_on: "2021-11-01", ended_on: "2021-11-30")
    end

    travel_to "2021-11-08 11:59 +01" do
      visit "/shop"
      expect(current_path).to eq "/shop"
      expect(page).to have_content "Votre commande peut-être passée ou modifié jusqu'au lundi 8 novembre 2021, 12:00."
    end
    travel_to "2021-11-08 12:01 +01" do
      visit "/shop"
      expect(current_path).to eq "/shop"
      expect(page).to have_content "Il n'est plus possible de passer commande pour cette livraison."
      expect(page).to have_link "Livraison du mercredi 17 novembre 2021", href: "/shop/next"
    end
  end

  specify "shop delivery open/closed depending date and depot" do
    Current.org.update!(
      shop_delivery_open_delay_in_days: 2,
      shop_delivery_open_last_day_end_time: Tod::TimeOfDay.parse("12:00:00"))

    depot = create(:depot, id: 1)
    create(:depot, id: 2)

    travel_to "2021-01-01" do
      create(:delivery, shop_open: true, shop_open_for_depot_ids: [ 2 ], date: "2021-11-10")
      create(:delivery, shop_open: true, shop_open_for_depot_ids: [ 1, 2 ], date: "2021-11-17")
      create(:delivery, shop_open: true, shop_open_for_depot_ids: [ 2 ], date: "2021-11-24")
      create(:delivery, shop_open: true, shop_open_for_depot_ids: [ 1, 2 ], date: "2021-11-30")
      create(:membership, member: member, depot: depot, started_on: "2021-11-01", ended_on: "2021-11-30")
    end

    travel_to "2021-11-08 11:59 +01" do
      visit "/shop"
      expect(current_path).to eq "/shop"
      expect(page).to have_content "Épicerie\n⤷ 17 novembre 2021"
      expect(page).to have_content "Livraison du mercredi 17 novembre 2021\nVotre commande peut-être passée ou modifié jusqu'au lundi 15 novembre 2021, 12:00."
    end
    travel_to "2021-11-15 12:01 +01" do
      visit "/shop"
      expect(current_path).to eq "/shop"
      expect(page).to have_content "Épicerie\n⤷ 17 novembre 2021"
      expect(page).to have_content "Il n'est plus possible de passer commande pour cette livraison."
      expect(page).to have_link "Livraison du mardi 30 novembre 2021", href: "/shop/next"
    end
  end

  specify "add product to cart" do
    product1 =
      create(:shop_product,
        name: "Farine de sarrasin",
        variants_attributes: {
          "0" => {
            name: "1 kg",
            price: 10,
            stock: 3
          },
          "1" => {
            name: "2 kg",
            price: 10,
            stock: 0,
            available: false
          }
        })
    product2 =
      create(:shop_product,
        name: "Farine de seigle",
        variants_attributes: {
          "0" => {
            name: "1 kg",
            price: 5
          },
          "1" => {
            name: "2 kg",
            price: 10,
            stock: 0
          }
        })
    product3 =
      create(:shop_product,
        name: "Indisponible",
        available: false,
        variants_attributes: {
          "0" => {
            name: "1 kg",
            price: 5
          }
        })


    travel_to "2021-11-08 08:00 +01" do
      delivery = create(:delivery, shop_open: true, date: "2021-11-10")
      create(:membership, member: member, started_on: "2021-11-01", ended_on: "2021-11-30")

      visit "/shop"

      expect(page).not_to have_selector "#product_variant_#{product1.variants.second.id}"
      expect(page).to have_selector "#product_variant_#{product2.variants.second.id}"
      expect(page).not_to have_selector "#product_variant_#{product3.variants.first.id}"
      expect(page).to have_content "Farine de sarrasin"
      within("#product_variant_#{product1.variants.first.id}") do
        expect(page).to have_content "3 disponibles"
        click_button "Ajouter au panier"
        expect(page).to have_content "2 disponibles"
        click_button "Ajouter au panier"
        expect(page).to have_content "1 disponible"
        click_button "Ajouter au panier"
        expect(page).to have_content "0 disponible"
        expect(page).not_to have_button("Ajouter au panier")
      end
      within("#product_variant_#{product2.variants.first.id}") do
        click_button "Ajouter au panier"
      end

      within("#cart") do
        expect(page).to have_content "4 Produits\nCHF 35.00"
      end
    end

    order = member.shop_orders.last
    expect(order.items.sum(:quantity)).to eq 4
    expect(order.amount).to eq 35
  end

  specify "shop special delivery" do
    product =
      create(:shop_product,
        name: "Farine de sarrasin",
        variants_attributes: {
          "0" => {
            name: "1 kg",
            price: 10,
            stock: 3
          },
          "1" => {
            name: "2 kg",
            price: 10,
            stock: 0,
            available: false
          }
        })
    other_product = create(:shop_product)
    create(:shop_special_delivery, date: "2022-12-08", products: [ product ])

    travel_to "2022-11-08 11:59 +01" do
      visit "/shop"
      expect(current_path).not_to eq "/shop"

      expect(page).to have_content "Épicerie"
      expect(page).to have_content "⤷ 8 décembre 2022"

      click_link "⤷ 8 décembre 2022"

      expect(current_path).to eq "/shop/special/2022-12-08"
      expect(page).to have_content "Livraison spéciale du jeudi 8 décembre 2022"

      expect(page).to have_selector "#product_variant_#{product.variants.first.id}"
      expect(page).not_to have_selector "#product_variant_#{product.variants.second.id}"
      expect(page).not_to have_selector "#product_variant_#{other_product.variants.first.id}"

      within("#product_variant_#{product.variants.first.id}") do
        expect(page).to have_content "3 disponibles"
        click_button "Ajouter au panier"
        expect(page).to have_content "2 disponibles"
      end

      within("#cart") do
        expect(page).to have_content "1 Produit\nCHF 10.00"
      end
    end
  end

  specify "shop special delivery with custom title" do
    create(:shop_special_delivery, date: "2024-04-24", title: "Fête du village")

    travel_to "2024-01-04" do
      visit "/shop"
      expect(current_path).not_to eq "/shop"

      expect(page).to have_content "Épicerie"
      expect(page).to have_content "⤷ 24 avril 2024"

      click_link "⤷ 24 avril 2024"

      expect(current_path).to eq "/shop/special/2024-04-24"
      expect(page).to have_content "Fête du village du mercredi 24 avril 2024"
    end
  end
end
