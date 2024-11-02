# frozen_string_literal: true

require "rails_helper"

describe "Memberships Renewal" do
  let(:basket_size) { create(:basket_size, name: "Petit") }
  let(:depot) { create(:depot, name: "Joli Lieu") }
  let(:member) { create(:member) }

  before do
    Current.org.update!(billing_year_divisions: [ 1, 4, 12 ])
    MailTemplate.find_by(title: :membership_renewal).update!(active: true)
    Capybara.app_host = "http://membres.acme.test"
  end

  specify "renew membership", freeze: "2020-09-30" do
    big_basket = create(:basket_size, name: "Grand")
    membership = create(:membership,
      member: member,
      billing_year_division: 4,
      basket_size: basket_size,
      depot: depot)
    create_deliveries(1, Current.org.fiscal_year_for(2021))
    new_depot = create(:depot, name: "Nouveau Lieu")
    membership.open_renewal!
    complement = create(:basket_complement,
      name: "Oeufs",
      delivery_ids: Delivery.future_year.pluck(:id))

    login(member)

    expect(menu_nav).to include("Abonnement\n⤷ Renouvellement ?")
    click_on "Abonnement"

    choose "Renouveler mon abonnement"
    click_on "Suivant"

    expect(page).to have_selector("turbo-frame#pricing", text: "CHF 30.00/an")

    choose "Nouveau Lieu"
    choose "Grand PUBLIC"
    fill_in "Oeufs", with: "2"

    choose "Mensuel"

    fill_in "Remarque(s)", with: "Plus d'épinards!"

    click_on "Confirmer"

    expect(page).to have_selector(".flash",
      text: "Votre abonnement a été renouvelé. Merci!")

    expect(menu_nav).to include("Abonnement\n⤷ En cours")
    within "ul#2021" do
      expect(page).to have_content "1 janvier 2021 – 31 décembre 2021"
      expect(page).to have_content "Grand PUBLIC"
      expect(page).to have_content "2x Oeufs"
      expect(page).to have_content "Nouveau Lieu"
      expect(page).to have_content "1 Livraison"
      expect(page).to have_content "½ Journées: 2 demandées"
      expect(page).to have_content "CHF 38.40"
    end
    expect(membership.reload).to have_attributes(
      billing_year_division: 4,
      depot: depot,
      renew: true,
      renewal_annual_fee: nil,
      renewal_opened_at: Time.current,
      renewed_at: Time.current,
      renewal_note: "Plus d'épinards!")
    expect(membership).to be_renewed
    expect(membership.renewed_membership).to have_attributes(
      billing_year_division: 12,
      renew: true,
      started_on: Date.parse("2021-01-01"),
      ended_on: Date.parse("2021-12-31"),
      basket_size: big_basket,
      depot: new_depot,
      delivery_cycle: new_depot.delivery_cycles.greatest)
    expect(membership.renewed_membership.memberships_basket_complements.first).to have_attributes(
      basket_complement_id: complement.id,
      quantity: 2)
  end

  specify "renew membership with a new deliveries cycle", freeze: "2020-09-30" do
    big_basket = create(:basket_size, name: "Grand")
    membership = create(:membership,
      member: member,
      basket_size: basket_size,
      depot: depot)
    new_cycle = create(:delivery_cycle,
      public_name: "Nouveau cycle",
      results: :odd,
      depots: [ depot ])
    create_deliveries(2, Current.org.fiscal_year_for(2021))
    membership.open_renewal!

    login(member)

    expect(menu_nav).to include("Abonnement\n⤷ Renouvellement ?")
    click_on "Abonnement"

    choose "Renouveler mon abonnement"
    click_on "Suivant"

    expect(page).to have_selector("turbo-frame#pricing", text: "CHF 60.00/an")

    choose "Nouveau cycle"

    click_on "Confirmer"

    expect(page).to have_selector(".flash",
      text: "Votre abonnement a été renouvelé. Merci!")

    expect(menu_nav).to include("Abonnement\n⤷ En cours")
    within "ul#2021" do
      expect(page).to have_content "1 janvier 2021 – 31 décembre 2021"
      expect(page).to have_content "Petit PUBLIC"
      expect(page).to have_content "Joli Lieu"
      expect(page).to have_content "1 Livraison"
      expect(page).to have_content "½ Journées: 2 demandées"
      expect(page).to have_content "CHF 30.00"
    end
    expect(membership.reload).to have_attributes(
      renew: true,
      renewal_annual_fee: nil,
      renewal_opened_at: Time.current,
      renewed_at: Time.current)
    expect(membership).to be_renewed
    expect(membership.renewed_membership).to have_attributes(
      renew: true,
      started_on: Date.parse("2021-01-01"),
      ended_on: Date.parse("2021-12-31"),
      depot: depot,
      delivery_cycle: new_cycle)
  end

  specify "renew membership (with basket_price_extra)", freeze: "2020-09-30" do
    Current.org.update!(
      basket_price_extra_public_title: "Cotistation solidaire",
      basket_price_extras: "0, 1, 2, 4, 8",
      basket_price_extra_label: "+ {{ extra | ceil }}.-/panier")
    membership = create(:membership,
      member: member,
      basket_size: basket_size,
      depot: depot)
    create_deliveries(1, Current.org.fiscal_year_for(2021))
    big_basket = create(:basket_size, name: "Grand")
    membership.open_renewal!

    login(member)

    expect(menu_nav).to include("Abonnement\n⤷ Renouvellement ?")
    click_on "Abonnement"

    choose "Renouveler mon abonnement"
    click_on "Suivant"

    expect(page).to have_selector("turbo-frame#pricing", text: "CHF 30.00/an")

    choose "Grand PUBLIC"

    expect(page).to have_content "Cotistation solidaire"
    choose "+ 8.-/panier"

    fill_in "Remarque(s)", with: "Plus d'épinards!"

    click_on "Confirmer"

    expect(page).to have_selector(".flash",
      text: "Votre abonnement a été renouvelé. Merci!")

    expect(menu_nav).to include("Abonnement\n⤷ En cours")
    within "ul#2021" do
      expect(page).to have_content "1 janvier 2021 – 31 décembre 2021"
      expect(page).to have_content "Grand PUBLIC"
      expect(page).to have_content "Joli Lieu"
      expect(page).to have_content "1 Livraison"
      expect(page).to have_content "½ Journées: 2 demandées"
      expect(page).to have_content "CHF 38.00"
    end
    expect(membership.reload).to have_attributes(
      renew: true,
      renewal_annual_fee: nil,
      renewal_opened_at: Time.current,
      renewed_at: Time.current,
      renewal_note: "Plus d'épinards!",
      basket_price_extra: 0)
    expect(membership).to be_renewed
    expect(membership.renewed_membership).to have_attributes(
      renew: true,
      started_on: Date.parse("2021-01-01"),
      ended_on: Date.parse("2021-12-31"),
      basket_size: big_basket,
      basket_price_extra: 8)
  end

  specify "renew membership (with basket_price_extra but salary basket)", freeze: "2020-09-30" do
    Current.org.update!(
      basket_price_extra_public_title: "Cotistation solidaire",
      basket_price_extras: "0, 1, 2, 4, 8",
      basket_price_extra_label: "+ {{ extra | ceil }}.-/panier")
    member.update!(salary_basket: true)
    membership = create(:membership,
      member: member,
      basket_size: basket_size,
      depot: depot)
    create_deliveries(1, Current.org.fiscal_year_for(2021))
    big_basket = create(:basket_size, name: "Grand")
    membership.open_renewal!

    login(member)

    expect(menu_nav).to include("Abonnement\n⤷ Renouvellement ?")
    click_on "Abonnement"

    choose "Renouveler mon abonnement"
    click_on "Suivant"

    choose "Grand PUBLIC"

    expect(page).not_to have_content "Cotistation solidaire"

    fill_in "Remarque(s)", with: "Plus d'épinards!"

    click_on "Confirmer"

    expect(page).to have_selector(".flash",
      text: "Votre abonnement a été renouvelé. Merci!")

    expect(menu_nav).to include("Abonnement\n⤷ En cours")
    within "ul#2021" do
      expect(page).to have_content "1 janvier 2021 – 31 décembre 2021"
      expect(page).to have_content "Grand PUBLIC"
      expect(page).to have_content "Joli Lieu"
      expect(page).to have_content "1 Livraison"
      expect(page).to have_content "½ Journées: Aucun engagement"
      expect(page).to have_content "Paniers salaire"
    end
    expect(membership.reload).to have_attributes(
      renew: true,
      renewal_annual_fee: nil,
      renewal_opened_at: Time.current,
      renewed_at: Time.current,
      renewal_note: "Plus d'épinards!",
      basket_price_extra: 0)
    expect(membership).to be_renewed
    expect(membership.renewed_membership).to have_attributes(
      renew: true,
      started_on: Date.parse("2021-01-01"),
      ended_on: Date.parse("2021-12-31"),
      basket_size: big_basket,
      basket_price_extra: 0)
  end

  specify "renew membership (salary basket)", freeze: "2024-09-30" do
    member.update!(salary_basket: true)
    membership = create(:membership, member: member)
    create_deliveries(1, Current.org.fiscal_year_for(2025))
    membership.open_renewal!

    login(member)

    expect(menu_nav).to include("Abonnement\n⤷ Renouvellement ?")
    click_on "Abonnement"

    choose "Renouveler mon abonnement"
    click_on "Suivant"

    expect(page).to have_selector("turbo-frame#pricing", text: "Panier salaire (gratuit)")
  end

  specify "cancel membership", freeze: "2020-09-30" do
    membership = create(:membership,
      member: member,
      basket_size: basket_size,
      depot: depot)
    create_deliveries(1, Current.org.fiscal_year_for(2021))
    membership.open_renewal!

    login(member)

    expect(menu_nav).to include("Abonnement\n⤷ Renouvellement ?")
    click_on "Abonnement"

    choose "Résilier mon abonnement"
    click_on "Suivant"

    fill_in "Remarque(s)", with: "Pas assez d'épinards!"
    check "Pour soutenir l'association, je continue à payer la cotisation annuelle dès l'an prochain."

    click_on "Confirmer"

    expect(page).to have_selector(".flash",
      text: "Votre abonnement a été résilié.")

    expect(menu_nav).to include("Abonnement\n⤷ En cours")
    expect(page).to have_content "Votre abonnement a été résilié et se terminera après la livraison du 7 janvier 2020."
    expect(membership.reload).to have_attributes(
      renew: false,
      renewal_opened_at: nil,
      renewal_annual_fee: 30,
      renewal_note: "Pas assez d'épinards!")
    expect(membership).to be_canceled
  end
end
