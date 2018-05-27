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

      create(:distribution, name: 'Jardin de la main', price: 0)
      create(:distribution, name: 'Vélo', price: 8, address: 'Uniquement à Neuchâtel')
      create(:distribution, name: 'Domicile', visible: false)

      visit "/new"

      fill_in "Nom(s) de famille et prénom(s)", with: 'John et Jame Doe'
      fill_in 'Adresse', with: 'Nowhere srteet 2'
      fill_in 'NPA', with: '2042'
      fill_in 'Ville', with: 'Moon City'

      fill_in 'Email(s)', with: 'john@doe.com, jane@doe.com'
      fill_in 'Téléphone(s)', with: '077 142 42 42, 077 143 44 44'

      choose 'Eveil'
      check 'Oeufs'
      check 'Pain'
      choose 'Vélo'

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
      expect(member.waiting_distribution.name).to eq 'Vélo'
      expect(member.waiting_basket_complements.pluck(:name)).to eq %w[Oeufs Pain]
    end

    it 'creates a new support member' do
      Current.acp.update!(languages: %w[fr de])
      DeliveriesHelper.create_deliveries(40)
      create(:basket_size, :small)
      create(:basket_size, :big)

      create(:distribution, name: 'Jardin de la main', price: 0)

      visit "/new"

      fill_in "Nom(s) de famille et prénom(s)", with: 'John et Jame Doe'
      fill_in 'Adresse', with: 'Nowhere srteet 2'
      fill_in 'NPA', with: '2042'
      fill_in 'Ville', with: 'Moon City'

      fill_in 'Email(s)', with: 'john@doe.com, jane@doe.com'
      fill_in 'Téléphone(s)', with: '077 142 42 42, 077 143 44 44'

      choose 'Aucun, devenir membre de soutien'

      check "J'ai lu attentivement et accepte avec plaisir le règlement."

      click_button 'Envoyer'

      expect(page).to have_content 'Merci pour votre inscription!'

      member = Member.last
      expect(member).to be_support_member
      expect(member.attributes.symbolize_keys).to match hash_including(
        name: 'John et Jame Doe',
        address: 'Nowhere srteet 2',
        zip: '2042',
        city: 'Moon City',
        emails: 'john@doe.com, jane@doe.com',
        phones: '+41771424242, +41771434444',
        language: 'fr')
      expect(member.waiting_basket_size).to be_nil
      expect(member.waiting_distribution).to be_nil
      expect(member.billing_year_division).to eq 1
    end
  end

  context 'existing member token' do
    let!(:halfday) { create(:halfday, date: 4.days.from_now) }

    it 'shows current membership info and halfdays count' do
      create(:basket_complement, id: 1, name: 'Oeufs')
      member.current_year_membership.update!(
        annual_halfday_works: 3,
        basket_size: create(:basket_size, name: 'Petit'),
        distribution: create(:distribution, name: 'Jardin de la main'),
        memberships_basket_complements_attributes: {
          '0' => { basket_complement_id: 1 }
        })

      visit "/#{member.token}"

      expect(page).to have_content 'Panier: Petit'
      expect(page).to have_content 'Complément panier: Oeufs'
      expect(page).to have_content 'Distribution: Jardin de la main'
      expect(page).to have_content "½ Journées (#{Date.current.year}): 0/3"
    end

    it 'shows current membership info with custom coming basket' do
      create(:basket_complement, id: 1, name: 'Oeufs')
      member.current_year_membership.update!(
        annual_halfday_works: 3,
        basket_size: create(:basket_size, name: 'Petit'),
        distribution: create(:distribution, name: 'Jardin de la main'),
        memberships_basket_complements_attributes: {
          '0' => { basket_complement_id: 1 }
        })
      member.next_basket.update!(
        basket_size: create(:basket_size, name: 'Grand'),
        quantity: 2,
        distribution: create(:distribution, name: 'Vélo'))

      visit "/#{member.token}"

      expect(page).to have_content 'Panier: 2x Grand'
      expect(page).to have_content 'Complément panier: Oeufs'
      expect(page).to have_content 'Distribution: Vélo'
      expect(page).to have_content "½ Journées (#{Date.current.year}): 0/3"
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
        distribution: create(:distribution, name: 'Vélo'),
        memberships_basket_complements_attributes: {
          '0' => { basket_complement_id: 1 }
        })

      visit "/#{member.token}"

      expect(page).to have_content 'Panier: Grand'
      expect(page).to have_content 'Complément panier: Fromage'
      expect(page).to have_content 'Distribution: Vélo'
      expect(page).to have_content "½ Journées (#{Date.current.year + 1}): 0/4"
    end

    it 'shows with no membership' do
      member.current_year_membership.delete

      visit "/#{member.token}"

      expect(page).to have_content 'Aucun abonnement'
    end

    it 'adds new participation' do
      visit "/#{member.token}"

      choose "halfday_participation_halfday_id_#{halfday.id}"
      fill_in 'halfday_participation_participants_count', with: 3
      click_button 'Inscription'

      expect(page).to have_content('Merci pour votre inscription!')
      expect(page)
        .to have_content "#{I18n.l(halfday.date, format: :long).capitalize}, #{halfday.period}"
      within('ol.halfdays') do
        expect(page).not_to have_content 'covoiturage'
      end
    end

    it 'adds new participation with carpooling' do
      visit "/#{member.token}"

      choose "halfday_participation_halfday_id_#{halfday.id}"
      fill_in 'halfday_participation_participants_count', with: 3
      check 'halfday_participation_carpooling'
      fill_in 'carpooling_phone', with: '+41 77 447 58 31'
      click_button 'Inscription'

      expect(page).to have_content('Merci pour votre inscription!')
      within('ol.halfdays') do
        expect(page).to have_content 'covoiturage'
      end
    end

    it 'adds new participation with carpooling (default phone)' do
      visit "/#{member.token}"

      choose "halfday_participation_halfday_id_#{halfday.id}"
      fill_in 'halfday_participation_participants_count', with: 3
      check 'halfday_participation_carpooling'
      click_button 'Inscription'

      expect(page).to have_content('Merci pour votre inscription!')
      within('ol.halfdays') do
        expect(page).to have_content 'covoiturage'
      end
    end

    it 'deletes a participation' do
      halfday = create(:halfday_participation, member: member).halfday

      visit "/#{member.token}"

      part_text = "#{I18n.l(halfday.date, format: :long).capitalize}, #{halfday.period}"

      expect(page).to have_content part_text
      click_link 'annuler', match: :first
      expect(page).not_to have_content part_text
      expect(page).not_to have_content "Pour des raisons d'organisation,"
    end

    it 'cannot delete a participation when deadline is overdue' do
      Current.acp.update!(
        halfday_i18n_scope: 'basket_preparation',
        halfday_participation_deletion_deadline_in_days: 30)
      halfday = create(:halfday, date: 29.days.from_now)
      create(:halfday_participation,
        member: member,
        halfday: halfday,
        created_at: 25.hours.ago)

      visit "/#{member.token}"

      part_text = "#{I18n.l(halfday.date, format: :long).capitalize}, #{halfday.period}"

      expect(page).to have_content part_text
      expect(page).not_to have_content 'annuler'
      expect(page).to have_content "Pour des raisons d'organisation, les inscriptions aux mises en panier qui ont lieu dans moins de 30 jours ne peuvent plus être annulées. En cas d'empêchement, merci de nous contacter."
    end
  end
end
