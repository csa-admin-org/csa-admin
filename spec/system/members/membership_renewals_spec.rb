require 'rails_helper'

describe 'Memberships Renewal' do
  let(:basket_size) { create(:basket_size, name: 'Petit') }
  let(:depot) { create(:depot, name: 'Joli Lieu', fiscal_year: Current.fiscal_year) }
  let(:member) { create(:member) }

  before do
    MailTemplate.create! title: :membership_renewal, active: true
    Capybara.app_host = 'http://membres.ragedevert.test'
  end

  specify 'renew membership', freeze: '2020-09-30' do
    big_basket = create(:basket_size, name: 'Grand')
    membership = create(:membership,
      member: member,
      basket_size: basket_size,
      depot: depot)
    DeliveriesHelper.create_deliveries(1, Current.acp.fiscal_year_for(2021))
    membership.open_renewal!
    complement = create(:basket_complement,
      name: 'Oeufs',
      delivery_ids: Delivery.future_year.pluck(:id))

    login(member)

    within 'nav' do
      expect(page).to have_content "Abonnement\n⤷ Renouvellement ?"
    end

    click_on 'Abonnement'

    choose 'Renouveler mon abonnement'
    click_on 'Suivant'

    choose "Grand"
    fill_in 'Oeufs', with: '2'
    fill_in 'Remarque(s)', with: "Plus d'épinards!"

    click_on 'Confirmer'

    expect(page).to have_selector('.flash',
      text: 'Votre abonnement a été renouvelé. Merci!')

    within 'nav' do
      expect(page).to have_content "Abonnement\n⤷ En cours"
    end
    within 'ul#2021' do
      expect(page).to have_content '1 janvier 2021 – 31 décembre 2021'
      expect(page).to have_content 'Grand'
      expect(page).to have_content '2 x Oeufs'
      expect(page).to have_content 'Joli Lieu'
      expect(page).to have_content '1 Livraison'
      expect(page).to have_content '½ Journées: 2 demandées'
      expect(page).to have_content "CHF 38.40"
    end
    expect(membership.reload).to have_attributes(
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
      basket_size: big_basket)
    expect(membership.renewed_membership.memberships_basket_complements.first).to have_attributes(
      basket_complement_id: complement.id,
      quantity: 2)
  end

  specify 'renew membership (with basket_price_extra)', freeze: '2020-09-30' do
    Current.acp.update!(
      basket_price_extras: '0, 1, 2, 4, 8',
      basket_price_extra_label: "+ {{ extra | ceil }}.-/panier")
    membership = create(:membership,
      member: member,
      basket_size: basket_size,
      depot: depot)
    DeliveriesHelper.create_deliveries(1, Current.acp.fiscal_year_for(2021))
    big_basket = create(:basket_size, name: 'Grand')
    membership.open_renewal!

    login(member)

    within 'nav' do
      expect(page).to have_content "Abonnement\n⤷ Renouvellement ?"
    end
    click_on 'Abonnement'

    choose 'Renouveler mon abonnement'
    click_on 'Suivant'

    choose "Grand"
    choose "+ 8.-/panier"

    fill_in 'Remarque(s)', with: "Plus d'épinards!"

    click_on 'Confirmer'

    expect(page).to have_selector('.flash',
      text: 'Votre abonnement a été renouvelé. Merci!')

    within 'nav' do
      expect(page).to have_content "Abonnement\n⤷ En cours"
    end
    within 'ul#2021' do
      expect(page).to have_content '1 janvier 2021 – 31 décembre 2021'
      expect(page).to have_content 'Grand'
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
    DeliveriesHelper.create_deliveries(1, Current.acp.fiscal_year_for(2021))
    membership.open_renewal!

    login(member)

    within 'nav' do
      expect(page).to have_content "Abonnement\n⤷ Renouvellement ?"
    end
    click_on 'Abonnement'

    choose 'Résilier mon abonnement'
    click_on 'Suivant'

    fill_in 'Remarque(s)', with: "Pas assez d'épinards!"
    check "Pour soutenir l'association, je continue à payer la cotisation annuelle dès l'an prochain."

    click_on 'Confirmer'

    expect(page).to have_selector('.flash',
      text: 'Votre abonnement a été résilié.')

    within 'nav' do
      expect(page).to have_content "Abonnement\n⤷ En cours"
    end
    expect(page).to have_content 'Votre abonnement a été résilié et se terminera après la livraison du 6 octobre 2020.'
    expect(membership.reload).to have_attributes(
      renew: false,
      renewal_opened_at: nil,
      renewal_annual_fee: 30,
      renewal_note: "Pas assez d'épinards!")
    expect(membership).to be_canceled
  end
end
