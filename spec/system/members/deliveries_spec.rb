require "rails_helper"

describe "members page" do
  before { Capybara.app_host = "http://membres.ragedevert.test" }

  it "shows current membership info and activities count" do
    travel_to "2020-06-01" do
      create(:delivery, date: "2020-06-01")
      member = create(:member, :active)
      create(:basket_complement, id: 1, name: "Oeufs")
      member.current_year_membership.update!(
        activity_participations_demanded_annually: 3,
        basket_size: create(:basket_size, name: "Petit"),
        depot: create(:depot, name: "Jardin de la main"),
        memberships_basket_complements_attributes: {
          "0" => { basket_complement_id: 1 }
        })

      login(member)
      visit "/deliveries"

      expect(current_path).to eq "/deliveries"
      expect(page).to have_content "Petit PUBLIC"
      expect(page).to have_content "Oeufs"
      expect(page).to have_content "Jardin de la main PUBLIC"
    end
  end

  it "redirects when no membership" do
    login(create(:member))

    visit "/deliveries"

    expect(current_path).not_to eq "/deliveries"
  end

  specify "shows next basket depot public note", freeze: "2023-01-01" do
    depot = create(:depot, public_name: "Jardin de la main", public_note: "Note publique 42")
    member = create(:member)
    create(:membership, member: member, depot: depot)

    login(member)
    visit "/deliveries"

    expect(page).to have_content "Information: Jardin de la main"
    expect(page).to have_content "Note publique 42"
  end
end
