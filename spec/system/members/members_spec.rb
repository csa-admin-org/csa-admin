require 'rails_helper'

describe 'members page' do
  let(:member) { create(:member, :active, phones: '76 332 33 11') }

  before { Capybara.app_host = 'http://membres.ragedevert.test' }

  context 'new inscription' do
    it 'creates a new member with membership' do
      Current.acp.update!(
        languages: %w[fr de],
        basket_price_extra_title: 'Cotistation solidaire',
        basket_price_extras: '0, 1, 2, 4, 8',
        basket_price_extra_label: "+ {{ extra | ceil }}.-/panier")
      create_deliveries(2)
      create(:basket_size, :small)
      create(:basket_size, :big, form_detail: "Super Grand Panier, 66.50 CHF")

      create(:basket_complement, name: 'Oeufs', price: 4.8, form_detail: "Seulement 9.60 CHF")
      create(:basket_complement, name: 'Pain', price: 6.5, delivery_ids: Delivery.pluck(:id).select(&:odd?))

      create(:depot, name: 'Jardin de la main', price: 0, address: 'Rue de la main 6-7', zip: nil)
      create(:depot, name: 'Vélo', price: 8, address: 'Uniquement à Neuchâtel', zip: nil)
      create(:depot, name: 'Domicile', visible: false)

      visit '/new'

      expect(page).to have_selector('span',
        text: "Abondance PUBLICSuper Grand Panier, 66.50 CHF")
      expect(page).to have_selector('span',
        text: "Eveil PUBLICCHF 46.25 (~23.15 x 2 livraisons), 2 ½ journées")
      expect(page).to have_selector('span',
        text: "Aucun, devenir membre de soutienCotisation annuelle uniquement")

      expect(page).to have_selector('label',
        text: "Oeufs PUBLICSeulement 9.60 CHF")
      expect(page).to have_selector('label',
        text: "Pain PUBLICCHF 6.50 (6.50 x 1 livraison)")

      expect(page).to have_selector('span',
        text: "Jardin de la main PUBLICRue de la main 6-7")
      expect(page).to have_selector('span',
        text: "Vélo PUBLICCHF 16 (8.-/livraison), Uniquement à Neuchâtel")

      fill_in 'Nom(s) de famille et prénom(s)', with: 'John et Jame Doe'
      fill_in 'Adresse', with: 'Nowhere srteet 2'
      fill_in 'NPA', with: '2042'
      fill_in 'Ville', with: 'Moon City'
      select 'Suisse', from: 'Pays'

      fill_in 'Email(s)', with: 'john@doe.com, jane@doe.com'
      fill_in 'Téléphone(s)', with: '077 142 42 42, 077 143 44 44'

      choose 'Eveil PUBLIC'
      choose "+ 4.-/panier"
      fill_in 'Oeufs PUBLIC', with: '1'
      fill_in 'Pain PUBLIC', with: '2'
      choose 'Vélo PUBLIC'

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

    it 'creates a new member with delivery_cycle' do
      create_deliveries(2)
      create(:basket_size, :small)
      create(:basket_size, :big)

      create(:delivery_cycle, id: 10, visible: true, name: 'Toutes les semaines')
      create(:delivery_cycle, id: 20, visible: true, week_numbers: :odd, name: 'Semaines paires')
      create(:delivery_cycle, id: 30, visible: true, week_numbers: :even, name: 'Semaines impaires')
      create(:delivery_cycle, id: 40, visible: true, week_numbers: :odd, name: 'Semaines paires')
      create(:delivery_cycle, id: 50, visible: false, months: 1..4, name: 'Hiver')

      create(:depot, name: 'Jardin de la main', price: 0, address: 'Rue de la main 6-7', zip: nil, delivery_cycle_ids: [10])
      create(:depot, name: 'Vélo', price: 8, address: 'Uniquement à Neuchâtel', zip: nil, delivery_cycle_ids: [10, 30])
      create(:depot, name: 'Domicile', visible: false, delivery_cycle_ids: [10, 20])

      visit '/new'

      expect(page).to have_selector('span',
        text: "Abondance PUBLICCHF 33.25-66.50 (33.25 x 1-2 livraisons), 2 ½ journées")
      expect(page).to have_selector('span',
        text: "Eveil PUBLICCHF 23.15-46.25 (~23.15 x 1-2 livraisons), 2 ½ journées")
      expect(page).to have_selector('span',
        text: "Aucun, devenir membre de soutienCotisation annuelle uniquement")

      expect(page).to have_selector('span',
        text: "Jardin de la main PUBLIC2 livraisons, Rue de la main 6-7")
      expect(page).to have_selector('span',
        text: "Vélo PUBLICCHF 8-16 (8.- x 1-2 livraisons), Uniquement à Neuchâtel")

      fill_in 'Nom(s) de famille et prénom(s)', with: 'John et Jame Doe'
      fill_in 'Adresse', with: 'Nowhere srteet 2'
      fill_in 'NPA', with: '2042'
      fill_in 'Ville', with: 'Moon City'
      select 'Suisse', from: 'Pays'

      fill_in 'Email(s)', with: 'john@doe.com, jane@doe.com'
      fill_in 'Téléphone(s)', with: '077 142 42 42, 077 143 44 44'

      choose 'Eveil PUBLIC'

      choose '2.-/panier'

      choose 'Vélo PUBLIC'

      choose 'Semaines impaires PUBLIC', visible: false

      choose 'Trimestriel'

      check "J'ai lu attentivement et accepte avec plaisir le règlement."

      click_button 'Envoyer'

      expect(page).to have_content 'Merci pour votre inscription!'

      member = Member.last
      expect(member.waiting_basket_size.name).to eq 'Eveil'
      expect(member.waiting_depot.name).to eq 'Vélo'
      expect(member.waiting_delivery_cycle.name).to eq 'Semaines impaires'
      expect(member.waiting_basket_price_extra).to eq 2
    end

    it 'creates a new member with membership and alternative depots' do
      Current.acp.update!(allow_alternative_depots: true)

      create_deliveries(2)
      create(:basket_size, :small)
      create(:basket_size, :big)

      create(:depot, name: 'Jardin de la main', price: 0, address: 'Rue de la main 6-7', zip: nil)
      create(:depot, name: 'Vélo', price: 8, zip: nil)
      create(:depot, name: 'La Chaux-de-Fonds', price: 4, zip: nil)
      create(:depot, name: 'Neuchâtel', price: 4, zip: nil)

      visit '/new'

      expect(page).to have_selector('label',
          text: "Dépôt *")
      expect(page).to have_selector('span',
        text: "Jardin de la main PUBLICRue de la main 6-7")
      expect(page).to have_selector('span',
        text: "Vélo PUBLICCHF 16 (8.-/livraison)")
      expect(page).to have_selector('span',
        text: "Neuchâtel PUBLICCHF 8 (4.-/livraison)")
      expect(page).to have_selector('span',
        text: "La Chaux-de-Fonds PUBLICCHF 8 (4.-/livraison)")
      expect(page).to have_selector('label',
        text: "Dépôt(s) alternatifs(s)")

      fill_in 'Nom(s) de famille et prénom(s)', with: 'John et Jame Doe'
      fill_in 'Adresse', with: 'Nowhere srteet 2'
      fill_in 'NPA', with: '2042'
      fill_in 'Ville', with: 'Moon City'
      select 'Suisse', from: 'Pays'

      fill_in 'Email(s)', with: 'john@doe.com, jane@doe.com'
      fill_in 'Téléphone(s)', with: '077 142 42 42, 077 143 44 44'

      choose 'Eveil PUBLIC'

      choose 'Tarif de base'

      within '.member_waiting_depot_id' do
        choose 'Neuchâtel PUBLIC'
      end

      within '.member_waiting_alternative_depot_ids' do
        check 'Jardin de la main PUBLIC'
        check 'Vélo PUBLIC'
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

    it 'creates a new shop-only member' do
      Current.acp.update!(
        member_form_mode: 'shop',
        terms_of_service_url: nil,
        annual_fee: nil)

      depot = create(:depot, name: 'Jardin de la main', price: 42)

      visit '/new'

      expect(page).to have_content "Épicerie"
      expect(page).not_to have_content "Abonnement"
      expect(page).to have_content "Merci de choisir un dépôt pour vos commandes."

      fill_in 'Nom(s) de famille et prénom(s)', with: 'John et Jame Doe'
      fill_in 'Adresse', with: 'Nowhere srteet 2'
      fill_in 'NPA', with: '2042'
      fill_in 'Ville', with: 'Moon City'

      fill_in 'Email(s)', with: 'john@doe.com, jane@doe.com'
      fill_in 'Téléphone(s)', with: '077 142 42 42, 077 143 44 44'

      choose 'Jardin de la main PUBLIC'
      expect(page).not_to have_content "42.-/livraison"

      click_button 'Envoyer'

      expect(page).to have_content 'Merci pour votre inscription!'

      member = Member.last
      expect(member).to have_attributes(
        state: 'pending',
        name: 'John et Jame Doe',
        address: 'Nowhere srteet 2',
        zip: '2042',
        city: 'Moon City',
        emails: 'john@doe.com, jane@doe.com',
        phones: '+41771424242, +41771434444',
        language: 'fr')
      expect(member.waiting_basket_size).to be_nil
      expect(member.waiting_depot).to be_nil
      expect(member.shop_depot).to eq depot
      expect(member.annual_fee).to be_nil
      expect(member.billing_year_division).to eq 1
    end

    it 'creates a new support member (annual fee)' do
      Current.acp.update!(
        languages: %w[fr de],
        terms_of_service_url: nil,
        annual_fee: 42)
      create(:basket_size, :small)
      create(:basket_size, :big)

      create(:depot, name: 'Jardin de la main', price: 0)

      visit '/new'

      expect(page).to have_content "Chaque membre fait également partie de l'association et verse une cotisation annuelle de CHF 42 en plus de l'abonnement à son panier."

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
      create_deliveries(1)
      create(:basket_size, :small)
      create(:basket_size, :big)

      create(:depot, name: 'Jardin de la main', price: 0)

      visit '/new'

      expect(page).to have_content "Chaque membre fait également partie de la coopérative et se doit d'acquérir des parts sociales (CHF 250/part)."

      fill_in 'Nom(s) de famille et prénom(s)', with: 'John et Jame Doe'
      fill_in 'Adresse', with: 'Nowhere srteet 2'
      fill_in 'NPA', with: '2042'
      fill_in 'Ville', with: 'Moon City'

      fill_in 'Email(s)', with: 'john@doe.com, jane@doe.com'
      fill_in 'Téléphone(s)', with: '077 142 42 42, 077 143 44 44'

      choose 'Aucun, devenir membre de soutien'
      fill_in 'Nombre de parts sociales désiré', with: '3'

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
      expect(member.desired_acp_shares_number).to eq 3
      expect(member.billing_year_division).to eq 1
    end

    it 'hides billing_year_division when only one is configured' do
      Current.acp.update!(billing_year_divisions: [12])

      visit '/new'

      expect(page).not_to have_content 'Facturation'
      expect(page).not_to have_selector '#member_billing_year_division_input'
    end

    it 'shows only membership extra text' do
      default_text = "Chaque membre s'engage pour un abonnement d'une année"
      extra_text = 'Règles spéciales'
      Current.acp.update!(member_form_extra_text: extra_text)

      visit '/new'
      expect(page).to have_content default_text
      expect(page).to have_content extra_text

      Current.acp.update!(member_form_extra_text_only: true)
      visit '/new'

      expect(page).not_to have_content default_text
      expect(page).to have_content extra_text
    end

    it 'orders depots by form priority' do
      create(:depot, name: 'Jardin de la main', member_order_priority: 0)
      create(:depot, name: 'Vélo', member_order_priority: 1)
      create(:depot, name: 'Domicile', member_order_priority: 2)

      visit '/new'

      depots = all('.member_waiting_depot_id span label').map(&:text)
      expect(depots).to match([
        a_string_matching('Jardin de la main'),
        a_string_matching('Vélo'),
        a_string_matching('Domicile')
      ])
    end

    it 'notifies spam detection' do
      Current.acp.update!(
        languages: %w[fr de],
        terms_of_service_url: nil,
        annual_fee: 42)

      visit '/new'

      expect(page).to have_content "Chaque membre fait également partie de l'association et verse une cotisation annuelle de CHF 42 en plus de l'abonnement à son panier."

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

      expect(page).not_to have_selector('span',
        text: "Aucun, devenir membre de soutien(cotisation annuelle uniquement)")
      expect(page).not_to have_selector('span',
        text: "Aucun, devenir membre de soutien")
    end

    specify 'with different form modes' do
      Current.acp.update!(
        member_profession_form_mode: 'hidden',
        member_come_from_form_mode: 'required')

      visit '/new'

      expect(page).not_to have_text('Profession / Compétences')
      expect(page).to have_text('Comment avez-vous entendu parler de nous? *')

      click_button 'Envoyer'

      expect(page).to have_text('Comment avez-vous entendu parler de nous? * doit être rempli(e)')
    end

    specify 'pre-populate basket size and complements' do
      create_deliveries(2)
      create(:basket_size, :small, id: 55)
      create(:basket_size, :big, id: 66)

      create(:basket_complement, public_name: 'Oeufs', id: 11)
      create(:basket_complement, public_name: 'Pain', id: 22)
      create(:basket_complement, public_name: 'Fromage', id: 33)

      visit '/new?basket_size_id=55&basket_complements[11]=1&basket_complements[22]=2'

      small_basket_input = find_field('Eveil PUBLIC')
      expect(small_basket_input).to be_checked

      eggs_comples_input = find_field('Oeufs')
      expect(eggs_comples_input.value).to eq '1'
      bread_comples_input = find_field('Pain')
      expect(bread_comples_input.value).to eq '2'
      cheese_comples_input = find_field('Fromage')
      expect(cheese_comples_input.value).to eq '0'
    end
  end

  context 'existing member token' do
    it 'redirects to deliveries with next basket', freeze: '2022-01-01' do
      create(:delivery, date: '2022-02-02')
      login(create(:member, :active))

      visit '/'

      expect(current_path).to eq '/deliveries'
      expect(page).to have_selector('h1', text: 'Livraisons')

      expect(menu_nav).to eq [
        "Livraisons\n⤷ 2 février 2022",
        "Abonnement\n⤷ Période d'essai",
        "½ Journées\n⤷ 0 sur 2 demandées",
        "Facturation\n⤷ Consulter l'historique",
        "Absences\n⤷ Prévenez-nous!"
      ]
    end

    it 'redirects to activity_participations without next basket' do
      login(create(:member, state: 'active'))

      visit '/'

      expect(current_path).to eq '/activity_participations'
      expect(page).to have_selector('h1', text: '½ Journées')

      expect(menu_nav).to eq [
        "½ Journées\n⤷ Aucun engagement",
        "Facturation\n⤷ Consulter l'historique"
      ]
    end

    it 'redirects to shop', freeze: '2023-01-01' do
      current_acp.update!(
        features: ['shop'],
        shop_admin_only: false)

      create(:delivery, shop_open: true, date: '2023-02-01')
      login(create(:member, state: 'active', shop_depot: create(:depot)))

      visit '/'

      expect(current_path).to eq '/shop'
      expect(page).to have_selector('h1', text: 'Épicerie')

      expect(menu_nav).to eq [
        "Épicerie\n⤷ 1 février 2023",
        "Facturation\n⤷ Consulter l'historique"
      ]
    end

    it 'redirects to billing without activity feature' do
      current_acp.update!(features: [])

      login(create(:member, state: 'active'))

      visit '/'

      expect(current_path).to eq '/billing'
      expect(page).to have_selector('h1', text: 'Facturation')

      expect(menu_nav).to eq ["Facturation\n⤷ Consulter l'historique"]
    end

    it 'redirects inactive user to billing' do
      login(create(:member, :inactive))

      visit '/'

      expect(current_path).to eq '/billing'
      expect(page).to have_selector('h1', text: 'Facturation')

      expect(menu_nav).to eq ["Facturation\n⤷ Consulter l'historique"]
    end
  end
end
