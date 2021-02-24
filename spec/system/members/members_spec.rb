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

      create(:depot, name: 'Jardin de la main', price: 0, address: 'Rue de la main 6-7')
      create(:depot, name: 'Vélo', price: 8, address: 'Uniquement à Neuchâtel')
      create(:depot, name: 'Domicile', visible: false)

      visit '/new'

      expect(page).to have_selector('span.label',
        text: "AbondanceCHF 1'330(33.25 x 40 livraisons, 2 ½ journées)")
      expect(page).to have_selector('span.label',
        text: "EveilCHF 925(23.125 x 40 livraisons, 2 ½ journées)")
      expect(page).to have_selector('span.label',
        text: "Aucun, devenir membre de soutien(cotisation annuelle uniquement)")

      expect(page).to have_selector('label',
        text: "OeufsCHF 192(4.80 x 40 livraisons)")
      expect(page).to have_selector('label',
        text: "PainCHF 260(6.50 x 40 livraisons)")

      expect(page).to have_selector('span.label',
        text: "Jardin de la main(Rue de la main 6-7,")
      expect(page).to have_selector('span.label',
        text: "VéloCHF 320(8.-/livraison")

      fill_in 'Nom(s) de famille et prénom(s)', with: 'John et Jame Doe'
      fill_in 'Adresse', with: 'Nowhere srteet 2'
      fill_in 'NPA', with: '2042'
      fill_in 'Ville', with: 'Moon City'
      select 'Suisse', from: 'Pays'

      fill_in 'Email(s)', with: 'john@doe.com, jane@doe.com'
      fill_in 'Téléphone(s)', with: '077 142 42 42, 077 143 44 44'

      choose 'Eveil'
      choose "+ 4.-/panier"
      fill_in 'Oeufs', with: '1'
      fill_in 'Pain', with: '2'
      choose 'Vélo'

      choose 'Trimestriel'

      fill_in 'Profession', with: 'Pompier'
      fill_in 'Comment avez-vous entendu parler de nous?', with: 'Bouche à oreille'
      fill_in 'Remarque(s)', with: 'Vive Rage de Vert!'

      check "J'ai lu attentivement et accepte avec plaisir le règlement."

      click_button 'Envoyer'

      expect(page).to have_content 'Merci pour votre inscription!'

      member = Member.last
      expect(member).to have_attributes(
        name: 'John et Jame Doe',
        address: 'Nowhere srteet 2',
        country_code: 'CH',
        zip: '2042',
        city: 'Moon City',
        emails: 'john@doe.com, jane@doe.com',
        phones: '+41771424242, +41771434444',
        language: 'fr',
        profession: 'Pompier',
        come_from: 'Bouche à oreille',
        note: 'Vive Rage de Vert!')
      expect(member.waiting_basket_size.name).to eq 'Eveil'
      expect(member.waiting_basket_price_extra).to eq 4
      expect(member.waiting_depot.name).to eq 'Vélo'
      expect(member.waiting_basket_complements.map(&:name)).to eq %w[Oeufs Pain]
      expect(member.members_basket_complements.map(&:quantity)).to eq [1, 2]
      expect(member.annual_fee).to eq Current.acp.annual_fee
      expect(member.billing_year_division).to eq 4
    end

    it 'creates a new member with membership and alternative depots' do
      Current.acp.update!(allow_alternative_depots: true)

      DeliveriesHelper.create_deliveries(40)
      create(:basket_size, :small)
      create(:basket_size, :big)

      create(:depot, name: 'Jardin de la main', price: 0, address: 'Rue de la main 6-7')
      create(:depot, name: 'Vélo', price: 8)
      create(:depot, name: 'La Chaux-de-Fonds', price: 4)
      create(:depot, name: 'Neuchâtel', price: 4)

      visit '/new'

      expect(page).to have_selector('legend label',
        text: "Dépôt*")
      expect(page).to have_selector('span.label',
        text: "Jardin de la main(Rue de la main 6-7,")
      expect(page).to have_selector('span.label',
        text: "VéloCHF 320(8.-/livraison")
      expect(page).to have_selector('span.label',
        text: "NeuchâtelCHF 160(4.-/livraison")
      expect(page).to have_selector('span.label',
        text: "La Chaux-de-FondsCHF 160(4.-/livraison")
      expect(page).to have_selector('legend label',
        text: "Dépôt(s) alternatifs(s)")

      fill_in 'Nom(s) de famille et prénom(s)', with: 'John et Jame Doe'
      fill_in 'Adresse', with: 'Nowhere srteet 2'
      fill_in 'NPA', with: '2042'
      fill_in 'Ville', with: 'Moon City'
      select 'Suisse', from: 'Pays'

      fill_in 'Email(s)', with: 'john@doe.com, jane@doe.com'
      fill_in 'Téléphone(s)', with: '077 142 42 42, 077 143 44 44'

      choose 'Eveil'

      within '#member_waiting_depot_input' do
        choose 'Neuchâtel'
      end

      within '#member_waiting_alternative_depot_ids_input' do
        check 'Jardin de la main'
        check 'Vélo'
      end

      choose 'Trimestriel'

      fill_in 'Profession', with: 'Pompier'
      fill_in 'Comment avez-vous entendu parler de nous?', with: 'Bouche à oreille'
      fill_in 'Remarque(s)', with: 'Vive Rage de Vert!'

      check "J'ai lu attentivement et accepte avec plaisir le règlement."

      click_button 'Envoyer'

      expect(page).to have_content 'Merci pour votre inscription!'

      member = Member.last
      expect(member.waiting_depot.name).to eq 'Neuchâtel'
      expect(member.waiting_alternative_depots.map(&:name)).to eq ['Jardin de la main', 'Vélo']
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
      expect(member).to have_attributes(
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
      expect(member).to have_attributes(
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

    it 'hides billing_year_division when only one is configured' do
      Current.acp.update!(billing_year_divisions: [12])

      visit '/new'

      expect(page).not_to have_content 'Facturation'
      expect(page).not_to have_selector '#member_billing_year_division_input'
    end

    it 'notifies spam detection' do
      Current.acp.update!(
        languages: %w[fr de],
        terms_of_service_url: nil,
        annual_fee: 42)
      DeliveriesHelper.create_deliveries(40)

      visit '/new'

      expect(page).to have_content "Chaque membre fait également partie de l'association et verse une cotisation anuelle de CHF 42 en plus de l'abonnement à son panier."

      fill_in 'Nom(s) de famille et prénom(s)', with: 'Р РѕСЃСЃРёСЏ'
      fill_in 'Adresse', with: 'Р РѕСЃСЃРёСЏ'
      fill_in 'NPA', with: '999999'
      fill_in 'Ville', with: 'Р РѕСЃСЃРёСЏ'

      fill_in 'Email(s)', with: 'john@doe.com'

      choose 'Aucun, devenir membre de soutien'

      click_button 'Envoyer'

      expect(page).to have_content 'Merci pour votre inscription!'

      expect(Member.last).to be_nil
    end

    specify 'without annual fee or ACP shares' do
      Current.acp.update!(annual_fee: nil, share_price: nil)

      visit '/new'

      expect(page).not_to have_selector('span.label',
        text: "Aucun, devenir membre de soutien(cotisation annuelle uniquement)")
      expect(page).not_to have_selector('span.label',
        text: "Aucun, devenir membre de soutien")
    end
  end

  context 'existing member token' do
    around { |e| travel_to(Date.today.beginning_of_year + 6.months) { e.run } }

    it 'redirects to deliveries with next basket' do
      login(member)

      visit '/'

      expect(current_path).to eq '/deliveries'
      expect(page).to have_selector('h1', text: 'Livraisons')
    end

    it 'redirects to activity_participations without next basket' do
      login(create(:member))

      visit '/'

      expect(current_path).to eq '/activity_participations'
      expect(page).to have_selector('h1', text: '½ Journées')
    end

    it 'redirects to billing without activity feature' do
      current_acp.update!(features: [])

      login(create(:member))

      visit '/'

      expect(current_path).to eq '/billing'
      expect(page).to have_selector('h1', text: 'Facturation')
    end
  end
end
