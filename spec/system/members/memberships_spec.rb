require 'rails_helper'

describe 'Membership' do
  let(:basket_size) { create(:basket_size, name: 'Petit') }
  let(:depot) { create(:depot, name: 'Joli Lieu') }
  let(:member) { create(:member) }

  before do
    create_deliveries(2)
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

  specify 'active member with absence', freeze: '2020-01-01' do
    Current.acp.update!(trial_basket_count: 0)
    create(:membership,
      member: member,
      basket_size: basket_size,
      depot: depot)
    create(:absence,
      member: member,
      started_on: '2020-01-08',
      ended_on: '2020-02-01')

    login(member)

    within 'nav' do
      expect(page).to have_content "Abonnement\n⤷ En cours"
    end

    click_on 'Abonnement'

    within 'ul#2020' do
      expect(page).to have_content '1 janvier 2020 – 31 décembre 2020'
      expect(page).to have_content 'Petit PUBLIC'
      expect(page).to have_content 'Joli Lieu PUBLIC'
      expect(page).to have_content '2 Livraisons, une absence'
      expect(page).to have_content '½ Journées: 2 demandées'
      expect(page).to have_content "CHF 60.00"
    end
  end

  specify 'trial membership', freeze: '2020-01-01' do
    create(:membership,
      member: member,
      basket_size: basket_size,
      depot: depot,
      started_on: '2020-01-01')
    member.reload

    login(member)

    within 'nav' do
      expect(page).to have_content "Abonnement\n⤷ Période d'essai"
    end

    click_on 'Abonnement'

    within 'ul#2020' do
      expect(page).to have_content '1 janvier 2020 – 31 décembre 2020'
      expect(page).to have_content 'Petit PUBLIC'
      expect(page).to have_content 'Joli Lieu PUBLIC'
      expect(page).to have_content "2 Livraisons, encore 2 à l'essai et sans engagement"
      expect(page).to have_content '½ Journées: 2 demandées'
      expect(page).to have_content "CHF 60.00"
    end
  end

  specify 'future membership', freeze: '2020-01-01' do
    Current.acp.update!(trial_basket_count: 0)
    create(:membership,
      member: member,
      basket_size: basket_size,
      depot: depot,
      started_on: '2020-01-10')
    member.reload

    login(member)

    within 'nav' do
      expect(page).to have_content "Abonnement\n⤷ À venir"
    end

    click_on 'Abonnement'

    within 'ul#2020' do
      expect(page).to have_content '10 janvier 2020 – 31 décembre 2020'
      expect(page).to have_content 'Petit PUBLIC'
      expect(page).to have_content 'Joli Lieu PUBLIC'
      expect(page).to have_content '1 Livraison'
      expect(page).to have_content '½ Journées: 1 demandée'
      expect(page).to have_content "CHF 30"
    end
  end
end
