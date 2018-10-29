require 'rails_helper'

describe 'members page' do
  let(:member) { create(:member, :active, phones: '76 332 33 11') }

  before { Capybara.app_host = 'http://membres.ragedevert.test' }

  context 'new inscription' do
    it 'creates a new member with membership' do
      Current.acp.update!(languages: %w[fr de])
      DeliveriesHelper.create_deliveries(40)
      create(:basket_size, :small)
      create(:basket_size, :big)

      create(:basket_complement, name: 'Oeufs', price: 4.8, deliveries_count: 40)
      create(:basket_complement, name: 'Pain', price: 6.5, deliveries_count: 20)

      create(:depot, name: 'Jardin de la main', price: 0)
      create(:depot, name: 'Vélo', price: 8, address: 'Uniquement à Neuchâtel')
      create(:depot, name: 'Domicile', visible: false)

      visit '/new'

      fill_in 'Nom(s) de famille et prénom(s)', with: 'John et Jame Doe'
      fill_in 'Adresse', with: 'Nowhere srteet 2'
      fill_in 'NPA', with: '2042'
      fill_in 'Ville', with: 'Moon City'

      fill_in 'Email(s)', with: 'john@doe.com, jane@doe.com'
      fill_in 'Téléphone(s)', with: '077 142 42 42, 077 143 44 44'

      choose 'Eveil'
      check 'Oeufs'
      check 'Pain'
      choose 'Vélo'

      choose 'Trimestriel'

      fill_in 'Profession', with: 'Pompier'
      fill_in "Comment avez-vous entendu parler de nous?", with: 'Bouche à oreille'
      fill_in "Remarque(s)", with: 'Vive Rage de Vert!'

      check "J'ai lu attentivement et accepte avec plaisir le règlement."

      click_button 'Envoyer'

      expect(page).to have_content 'Merci pour votre inscription!'

      member = Member.last
      expect(member.attributes.symbolize_keys).to match hash_including(
        name: 'John et Jame Doe',
        address: 'Nowhere srteet 2',
        zip: '2042',
        city: 'Moon City',
        emails: 'john@doe.com, jane@doe.com',
        phones: '+41771424242, +41771434444',
        language: 'fr',
        profession: 'Pompier',
        come_from: 'Bouche à oreille',
        note: 'Vive Rage de Vert!')
      expect(member.waiting_basket_size.name).to eq 'Eveil'
      expect(member.waiting_depot.name).to eq 'Vélo'
      expect(member.waiting_basket_complements.map(&:name)).to eq %w[Oeufs Pain]
      expect(member.annual_fee).to eq Current.acp.annual_fee
      expect(member.billing_year_division).to eq 4
    end

    it 'creates a new support member (annual fee)' do
      Current.acp.update!(
        languages: %w[fr de],
        terms_of_service_url: nil,
        annual_fee: 42)
      DeliveriesHelper.create_deliveries(40)
      create(:basket_size, :small)
      create(:basket_size, :big)

      create(:depot, name: 'Jardin de la main', price: 0)

      visit '/new'

      expect(page).to have_content "Chaque membre fait également partie de l'association et verse une cotisation anuelle de CHF 42 en plus de l'abonnement à son panier."

      fill_in 'Nom(s) de famille et prénom(s)', with: 'John et Jame Doe'
      fill_in 'Adresse', with: 'Nowhere srteet 2'
      fill_in 'NPA', with: '2042'
      fill_in 'Ville', with: 'Moon City'

      fill_in 'Email(s)', with: 'john@doe.com, jane@doe.com'
      fill_in 'Téléphone(s)', with: '077 142 42 42, 077 143 44 44'

      choose 'Aucun, devenir membre de soutien'

      click_button 'Envoyer'

      expect(page).to have_content 'Merci pour votre inscription!'

      member = Member.last
      expect(member.attributes.symbolize_keys).to match hash_including(
        name: 'John et Jame Doe',
        address: 'Nowhere srteet 2',
        zip: '2042',
        city: 'Moon City',
        emails: 'john@doe.com, jane@doe.com',
        phones: '+41771424242, +41771434444',
        language: 'fr')
      expect(member.waiting_basket_size).to be_nil
      expect(member.waiting_depot).to be_nil
      expect(member.annual_fee).to eq Current.acp.annual_fee
      expect(member.billing_year_division).to eq 1
    end

    it 'creates a new support member (acp_share)' do
      Current.acp.update!(
        languages: %w[fr de],
        terms_of_service_url: 'https://terms_of_service.com',
        statutes_url: 'https://statutes.com',
        annual_fee: nil,
        share_price: 250)
      DeliveriesHelper.create_deliveries(40)
      create(:basket_size, :small)
      create(:basket_size, :big)

      create(:depot, name: 'Jardin de la main', price: 0)

      visit '/new'

      expect(page).to have_content "Chaque membre fait également partie de l'association et se doit d'acquérir des parts sociales (CHF 250/part) en fonction de la taille de son panier. Ces parts sociales sont intégralement remboursées si le membre décide de quitter l'association."

      fill_in 'Nom(s) de famille et prénom(s)', with: 'John et Jame Doe'
      fill_in 'Adresse', with: 'Nowhere srteet 2'
      fill_in 'NPA', with: '2042'
      fill_in 'Ville', with: 'Moon City'

      fill_in 'Email(s)', with: 'john@doe.com, jane@doe.com'
      fill_in 'Téléphone(s)', with: '077 142 42 42, 077 143 44 44'

      choose 'Aucun, devenir membre de soutien'

      check "J'ai lu attentivement et accepte avec plaisir les statuts et le règlement."

      click_button 'Envoyer'

      expect(page).to have_content 'Merci pour votre inscription!'

      member = Member.last
      expect(member.attributes.symbolize_keys).to match hash_including(
        name: 'John et Jame Doe',
        address: 'Nowhere srteet 2',
        zip: '2042',
        city: 'Moon City',
        emails: 'john@doe.com, jane@doe.com',
        phones: '+41771424242, +41771434444',
        language: 'fr')
      expect(member.waiting_basket_size).to be_nil
      expect(member.waiting_depot).to be_nil
      expect(member.annual_fee).to be_nil
      expect(member.billing_year_division).to eq 1
    end
  end

  context 'existing member token' do
    before { login(member) }
    before { Timecop.freeze(Date.today.beginning_of_year + 6.months) }
    after { Timecop.return }

    it 'shows current membership info and halfdays count' do
      create(:basket_complement, id: 1, name: 'Oeufs')
      member.current_year_membership.update!(
        annual_halfday_works: 3,
        basket_size: create(:basket_size, name: 'Petit'),
        depot: create(:depot, name: 'Jardin de la main'),
        memberships_basket_complements_attributes: {
          '0' => { basket_complement_id: 1 }
        })

      visit '/'

      expect(page).to have_content 'Panier: Petit'
      expect(page).to have_content 'Complément panier: Oeufs'
      expect(page).to have_content 'Dépôt: Jardin de la main'
      expect(page).to have_content "0/3 effectuée(s)"
    end

    it 'shows current membership info with custom coming basket' do
      create(:basket_complement, id: 1, name: 'Oeufs')
      member.current_year_membership.update!(
        annual_halfday_works: 3,
        basket_size: create(:basket_size, name: 'Petit'),
        depot: create(:depot, name: 'Jardin de la main'),
        memberships_basket_complements_attributes: {
          '0' => { basket_complement_id: 1 }
        })
      member.next_basket.update!(
        basket_size: create(:basket_size, name: 'Grand'),
        quantity: 2,
        depot: create(:depot, name: 'Vélo'))

      visit '/'

      expect(page).to have_content 'Panier: 2x Grand'
      expect(page).to have_content 'Complément panier: Oeufs'
      expect(page).to have_content 'Dépôt: Vélo'
      expect(page).to have_content "0/3 effectuée(s)"
    end

    it 'shows next year membership info and halfdays count' do
      Delivery.create_all(40, Current.fiscal_year.beginning_of_year + 1.year)
      create(:basket_complement, id: 1, name: 'Fromage')
      member.current_year_membership.delete
      create(:membership,
        member: member,
        started_on: Date.current.beginning_of_year + 1.year,
        ended_on: Date.current.end_of_year + 1.year,
        annual_halfday_works: 4,
        basket_size: create(:basket_size, name: 'Grand'),
        depot: create(:depot, name: 'Vélo'),
        memberships_basket_complements_attributes: {
          '0' => { basket_complement_id: 1 }
        })

      visit '/'

      expect(page).to have_content 'Panier: Grand'
      expect(page).to have_content 'Complément panier: Fromage'
      expect(page).to have_content 'Dépôt: Vélo'
      expect(page).to have_content "0/4 effectuée(s)"
    end

    it 'shows with no membership' do
      member.current_year_membership.delete

      visit '/'

      expect(page).to have_content 'Aucun abonnement'
    end
  end
end
