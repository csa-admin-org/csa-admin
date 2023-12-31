require "rails_helper"

describe "Membership" do
  let(:basket_size) { create(:basket_size, name: "Petit") }
  let(:depot) { create(:depot, name: "Joli Lieu") }
  let(:member) { create(:member) }

  before do
    create_deliveries(2)
    Capybara.app_host = "http://membres.ragedevert.test"
  end

  specify "inactive member" do
    login(create(:member, :inactive))

    expect(menu_nav).to eq [ "Facturation\n⤷ Consulter l'historique" ]

    visit "http://membres.ragedevert.test/memberships"
    expect(current_path).to eq "/billing"
  end

  specify "active member with absence", freeze: "2020-01-01" do
    Current.acp.update!(trial_basket_count: 0)
    create(:membership,
      member: member,
      basket_size: basket_size,
      depot: depot)
    create(:absence,
      member: member,
      started_on: "2020-01-08",
      ended_on: "2020-02-01")

    login(member)

    expect(menu_nav).to include "Abonnement\n⤷ En cours"

    click_on "Abonnement"

    within "ul#2020" do
      expect(page).to have_content "1 janvier 2020 – 31 décembre 2020"
      expect(page).to have_content "Petit PUBLIC"
      expect(page).to have_content "Joli Lieu PUBLIC"
      expect(page).to have_content "2 Livraisons, une absence"
      expect(page).to have_content "½ Journées: 2 demandées"
      expect(page).to have_content "CHF 60.00"
    end
  end

  specify "trial membership", freeze: "2020-01-01" do
    create(:membership,
      member: member,
      basket_size: basket_size,
      depot: depot,
      started_on: "2020-01-01")
    member.reload

    login(member)

    expect(menu_nav).to include "Abonnement\n⤷ Période d'essai"

    click_on "Abonnement"

    within "ul#2020" do
      expect(page).to have_content "1 janvier 2020 – 31 décembre 2020"
      expect(page).to have_content "Petit PUBLIC"
      expect(page).to have_content "Joli Lieu PUBLIC"
      expect(page).to have_content "2 Livraisons, encore 2 à l'essai et sans engagement"
      expect(page).to have_content "½ Journées: 2 demandées"
      expect(page).to have_content "CHF 60.00"
    end
  end

  specify "future membership", freeze: "2020-01-01" do
    Current.acp.update!(trial_basket_count: 0)
    create(:membership,
      member: member,
      basket_size: basket_size,
      depot: depot,
      started_on: "2020-01-10")
    member.reload

    login(member)

    expect(menu_nav).to include "Abonnement\n⤷ À venir"

    click_on "Abonnement"

    within "ul#2020" do
      expect(page).to have_content "10 janvier 2020 – 31 décembre 2020"
      expect(page).to have_content "Petit PUBLIC"
      expect(page).to have_content "Joli Lieu PUBLIC"
      expect(page).to have_content "1 Livraison"
      expect(page).to have_content "½ Journées: 1 demandée"
      expect(page).to have_content "CHF 30"
    end
  end

  specify "update depot", freeze: "2022-01-01" do
    Current.acp.update!(membership_depot_update_allowed: true)

    depot_1 = create(:depot, public_name: "Joli Lieu")
    depot_2 = create(:depot, public_name: "Beau Lieu")

    create(:delivery, date: "2022-02-01")
    membership = create(:membership, member: member, depot: depot_1)
    basket = member.current_year_membership.baskets.first

    login(member)
    expect(menu_nav).to include "Abonnement\n⤷ Période d'essai"
    click_on "Abonnement"

    expect(current_path).to eq "/memberships"
    expect(page).to have_content "Joli Lieu"

    click_on "Modifier"
    choose "Beau Lieu"

    expect {
      click_on "Confirmer"
    }
      .to change { membership.reload.depot_id }.from(depot_1.id).to(depot_2.id)
      .and change { basket.reload.depot }.from(depot_1).to(depot_2)

    expect(current_path).to eq "/memberships"
    expect(page).to have_content "Beau Lieu"
  end
end
