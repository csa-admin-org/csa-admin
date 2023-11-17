require 'rails_helper'

describe 'Memberships Renewal' do
  let(:basket_size) { create(:basket_size, name: 'Petit') }
  let(:depot) { create(:depot, name: 'Joli Lieu') }
  let(:member) { create(:member) }

  before do
    MailTemplate.find_by(title: :membership_renewal).update!(active: true)
    Capybara.app_host = 'http://membres.ragedevert.test'
  end

  specify 'renew membership', freeze: '2020-09-30' do
    big_basket = create(:basket_size, name: 'Grand')
    membership = create(:membership,
      member: member,
      basket_size: basket_size,
      depot: depot)
    create_deliveries(1, Current.acp.fiscal_year_for(2021))
    new_depot = create(:depot, name: 'Nouveau Lieu')
    membership.open_renewal!
    complement = create(:basket_complement,
      name: 'Oeufs',
      delivery_ids: Delivery.future_year.pluck(:id))

    login(member)

    expect(menu_nav).to include("Abonnement\n⤷ Renouvellement ?")
    click_on 'Abonnement'

    choose 'Renouveler mon abonnement'
    click_on 'Suivant'

    choose "Nouveau Lieu"
    choose "Grand PUBLIC"
    fill_in 'Oeufs', with: '2'
    fill_in 'Remarque(s)', with: "Plus d'épinards!"

    click_on 'Confirmer'

    expect(page).to have_selector('.flash',
      text: 'Votre abonnement a été renouvelé. Merci!')

    expect(menu_nav).to include("Abonnement\n⤷ En cours")
    within 'ul#2021' do
      expect(page).to have_content '1 janvier 2021 – 31 décembre 2021'
      expect(page).to have_content 'Grand PUBLIC'
      expect(page).to have_content '2x Oeufs'
      expect(page).to have_content 'Nouveau Lieu'
      expect(page).to have_content '1 Livraison'
      expect(page).to have_content '½ Journées: 2 demandées'
      expect(page).to have_content "CHF 38.40"
    end
    expect(membership.reload).to have_attributes(
      depot: depot,
      renew: true,
      renewal_annual_fee: nil,
      renewal_opened_at: Time.current,
      renewed_at: Time.current,
      renewal_note: "Plus d'épinards!")
    expect(membership).to be_renewed
    expect(membership.renewed_membership).to have_attributes(
      renew: true,
      started_on: Date.parse('2021-01-01'),
      ended_on: Date.parse('2021-12-31'),
      basket_size: big_basket,
      depot: new_depot,
      delivery_cycle: new_depot.main_delivery_cycle)
    expect(membership.renewed_membership.memberships_basket_complements.first).to have_attributes(
      basket_complement_id: complement.id,
      quantity: 2)
  end

  specify 'renew membership with a new deliveries cycle', freeze: '2020-09-30' do
    big_basket = create(:basket_size, name: 'Grand')
    membership = create(:membership,
      member: member,
      basket_size: basket_size,
      depot: depot)
    depot.delivery_cycles.update_all(visible: true)
    new_cycle = create(:delivery_cycle,
      visible: true,
      public_name: 'Nouveau cycle',
      results: :odd,
      depots: [depot])
    create_deliveries(2, Current.acp.fiscal_year_for(2021))
    membership.open_renewal!

    login(member)

    expect(menu_nav).to include("Abonnement\n⤷ Renouvellement ?")
    click_on 'Abonnement'

    choose 'Renouveler mon abonnement'
    click_on 'Suivant'

    choose "Nouveau cycle"

    click_on 'Confirmer'

    expect(page).to have_selector('.flash',
      text: 'Votre abonnement a été renouvelé. Merci!')

    expect(menu_nav).to include("Abonnement\n⤷ En cours")
    within 'ul#2021' do
      expect(page).to have_content '1 janvier 2021 – 31 décembre 2021'
      expect(page).to have_content 'Petit PUBLIC'
      expect(page).to have_content 'Joli Lieu'
      expect(page).to have_content '1 Livraison'
      expect(page).to have_content '½ Journées: 2 demandées'
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
      started_on: Date.parse('2021-01-01'),
      ended_on: Date.parse('2021-12-31'),
      depot: depot,
      delivery_cycle: new_cycle)
  end

  specify 'renew membership (with basket_price_extra)', freeze: '2020-09-30' do
    Current.acp.update!(
      basket_price_extra_title: 'Cotistation solidaire',
      basket_price_extras: '0, 1, 2, 4, 8',
      basket_price_extra_label: "+ {{ extra | ceil }}.-/panier")
    membership = create(:membership,
      member: member,
      basket_size: basket_size,
      depot: depot)
    create_deliveries(1, Current.acp.fiscal_year_for(2021))
    big_basket = create(:basket_size, name: 'Grand')
    membership.open_renewal!

    login(member)

    expect(menu_nav).to include("Abonnement\n⤷ Renouvellement ?")
    click_on 'Abonnement'

    choose 'Renouveler mon abonnement'
    click_on 'Suivant'

    choose "Grand PUBLIC"
    choose "+ 8.-/panier"

    fill_in 'Remarque(s)', with: "Plus d'épinards!"

    click_on 'Confirmer'

    expect(page).to have_selector('.flash',
      text: 'Votre abonnement a été renouvelé. Merci!')

    expect(menu_nav).to include("Abonnement\n⤷ En cours")
    within 'ul#2021' do
      expect(page).to have_content '1 janvier 2021 – 31 décembre 2021'
      expect(page).to have_content 'Grand PUBLIC'
      expect(page).to have_content 'Joli Lieu'
      expect(page).to have_content '1 Livraison'
      expect(page).to have_content '½ Journées: 2 demandées'
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
      started_on: Date.parse('2021-01-01'),
      ended_on: Date.parse('2021-12-31'),
      basket_size: big_basket,
      basket_price_extra: 8)
  end

  specify 'cancel membership', freeze: '2020-09-30' do
    membership = create(:membership,
      member: member,
      basket_size: basket_size,
      depot: depot)
    create_deliveries(1, Current.acp.fiscal_year_for(2021))
    membership.open_renewal!

    login(member)

    expect(menu_nav).to include("Abonnement\n⤷ Renouvellement ?")
    click_on 'Abonnement'

    choose 'Résilier mon abonnement'
    click_on 'Suivant'

    fill_in 'Remarque(s)', with: "Pas assez d'épinards!"
    check "Pour soutenir l'association, je continue à payer la cotisation annuelle dès l'an prochain."

    click_on 'Confirmer'

    expect(page).to have_selector('.flash',
      text: 'Votre abonnement a été résilié.')

    expect(menu_nav).to include("Abonnement\n⤷ En cours")
    expect(page).to have_content 'Votre abonnement a été résilié et se terminera après la livraison du 7 janvier 2020.'
    expect(membership.reload).to have_attributes(
      renew: false,
      renewal_opened_at: nil,
      renewal_annual_fee: 30,
      renewal_note: "Pas assez d'épinards!")
    expect(membership).to be_canceled
  end
end
