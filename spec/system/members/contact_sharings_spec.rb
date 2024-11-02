# frozen_string_literal: true

require "rails_helper"

describe "Contact sharing" do
  let(:member) { create(:member) }

  before do
    Capybara.app_host = "http://membres.acme.test"
    current_org.update!(features: current_org.features + [ "contact_sharing" ])
    login(member)
  end

  around do |example|
    travel_to("2021-06-15") { example.run }
  end

  it "accepts to share contact" do
    create(:delivery, date: Date.tomorrow)
    depot = create(:depot, name: "Vin Libre")
    membership = create(:membership, member: member, depot: depot)

    visit "/"

    expect(menu_nav).to include("Copaniérage\n⤷ Vin Libre PUBLIC")

    click_on "Copaniérage"

    check "J'accepte de partager mes coordonnées avec les autres membres de mon dépôt."

    click_button "Partager"

    expect(page).to have_selector(".flash",
      text: "Vos coordonnées sont maintenant partagées avec les autres membres de votre dépôt!")
    expect(page).to have_content "Aucun autre membre ne partage ses coordonnées pour le moment!"
  end

  it "lists other members contact" do
    create(:delivery, date: Date.tomorrow)
    depot = create(:depot, name: "Vin Libre")
    create(:membership, member: member, depot: depot)
    member.update!(name: "John Doe", contact_sharing: true)
    jane = create(:member,
      name: "Jane",
      contact_sharing: true,
      phones: "+33 6 03 42 11 22",
      address: "Nowhere 42",
      zip: "4321",
      city: "Townhall")
    create(:membership, member: jane, depot: depot)

    visit "/contact_sharing"

    within "ul#members" do
      expect(page).not_to have_content "John Doe"
      expect(page).to have_content "+33 6 03 42 11 22"
      expect(page).to have_content "Nowhere 42"
      expect(page).to have_content "4321 Townhall"
    end

    expect(page).to have_content "Merci de nous contacter par email si vous désirez arrêter de partager vos coordonnées."
  end

  it "redirects when member is not active" do
    visit "/contact_sharing"

    expect(current_path).not_to eq "/contact_sharing"
  end

  it "redirects when contact_sharing is not a feature" do
    create(:membership, member: member)
    current_org.update!(features: [])

    visit "/contact_sharing"

    expect(current_path).not_to eq "/contact_sharing"
  end
end
