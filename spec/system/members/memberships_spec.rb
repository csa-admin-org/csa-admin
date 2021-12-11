require 'rails_helper'

describe 'Membership' do
  let(:basket_size) { create(:basket_size, name: 'Petit') }
  let(:depot) { create(:depot, name: 'Joli Lieu', fiscal_year: Current.fiscal_year) }
  let(:member) { create(:member) }

  before do
    Capybara.app_host = 'http://membres.ragedevert.test'
  end

  specify 'inactive member' do
    login(member)

    within 'nav' do
      expect(page).not_to have_content 'Abonnement'
    end

    visit 'http://membres.ragedevert.test/membership'
    expect(current_path).to eq '/activity_participations'
  end

  specify 'active member with absence', freeze: '2020-02-01' do
    create(:membership,
      member: member,
      basket_size: basket_size,
      depot: depot)
    create(:absence,
      member: member,
      started_on: '2020-03-01',
      ended_on: '2020-04-01')

    login(member)

    within 'nav' do
      expect(page).to have_content "Abonnement\n⤷ En cours"
    end

    click_on 'Abonnement'

    within 'ul#2020' do
      expect(page).to have_content '1 janvier 2020 – 31 décembre 2020'
      expect(page).to have_content 'Petit PUBLIC'
      expect(page).to have_content 'Joli Lieu PUBLIC'
      expect(page).to have_content '40 Livraisons, 5 absences'
      expect(page).to have_content '½ Journées: 2 demandées'
      expect(page).to have_content "CHF 1'200.00"
    end
  end

  specify 'trial membership', freeze: '2020-02-01' do
    create(:membership,
      member: member,
      basket_size: basket_size,
      depot: depot,
      started_on: '2020-02-01')
    member.reload

    login(member)

    within 'nav' do
      expect(page).to have_content "Abonnement\n⤷ Période d'essai"
    end

    click_on 'Abonnement'

    within 'ul#2020' do
      expect(page).to have_content '1 février 2020 – 31 décembre 2020'
      expect(page).to have_content 'Petit PUBLIC'
      expect(page).to have_content 'Joli Lieu PUBLIC'
      expect(page).to have_content "36 Livraisons, encore 4 à l'essai et sans engagement"
      expect(page).to have_content '½ Journées: 2 demandées'
      expect(page).to have_content "CHF 1'080.00"
    end
  end

  specify 'future membership', freeze: '2020-02-01' do
    Current.acp.update!(trial_basket_count: 0)
    create(:membership,
      member: member,
      basket_size: basket_size,
      depot: depot,
      started_on: '2020-06-01')
    member.reload

    login(member)

    within 'nav' do
      expect(page).to have_content "Abonnement\n⤷ À venir"
    end

    click_on 'Abonnement'

    within 'ul#2020' do
      expect(page).to have_content '1 juin 2020 – 31 décembre 2020'
      expect(page).to have_content 'Petit PUBLIC'
      expect(page).to have_content 'Joli Lieu PUBLIC'
      expect(page).to have_content '19 Livraisons'
      expect(page).to have_content '½ Journées: 1 demandée'
      expect(page).to have_content "CHF 570"
    end
  end
end
