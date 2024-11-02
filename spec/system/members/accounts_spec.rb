# frozen_string_literal: true

require "rails_helper"

describe "Account" do
  let(:member) {
    create(:member,
      name: "Doe Jame and John",
      address: "Nowhere 1",
      zip: "1234",
      city: "Town",
      country_code: "CH",
      emails: "john@doe.com, jame@doe.com",
      phones: "076 123 45 67, +33 6 01 42 11 22")
  }

  before do
    Capybara.app_host = "http://membres.acme.test"
    login(member)
  end

  it "shows current member data" do
    visit "/"

    click_on "Doe Jame and John"

    expect(page).to have_content("Doe Jame and John")
    expect(page).to have_content("Nowhere 11234 TownSuisse")
    expect(page).to have_content("john@doe.com, jame@doe.com")
    expect(page).to have_content("076 123 45 67, +33 6 01 42 11 22")
  end

  it "edits current member data" do
    visit "/"

    click_on "Doe Jame and John"
    click_on "Modifier les données du compte"

    fill_in "Nom", with: "Doe Jame & John"
    fill_in "member_zip", with: "12345"
    fill_in "member_city", with: "Villar"
    select "Allemagne", from: "member_country_code"

    click_button "Soumettre"

    expect(page).to have_content("Doe Jame & John")
    expect(page).to have_content("Nowhere 112345 VillarAllemagne")

    expect(member.audits.last).to have_attributes(
      actor: member,
      session: member.last_session,
      audited_changes: {
        "zip" => [ "1234", "12345" ],
        "city" => [ "Town", "Villar" ],
        "country_code" => [ "CH", "DE" ],
        "name" => [ "Doe Jame and John", "Doe Jame & John" ]
      })
  end

  specify "edit shop depot" do
    mega_depot = create(:depot, name: "Mega Depot")
    member.update!(shop_depot: mega_depot)
    giga_depot = create(:depot, name: "Giga Depot")

    visit "/"

    click_on "Doe Jame and John"
    expect(page).to have_content("Mega Depot")

    click_on "Modifier les données du compte"

    choose "Giga Depot"

    expect {
      click_button "Soumettre"
    }.to change { member.reload.shop_depot }.from(mega_depot).to(giga_depot)

    expect(page).to have_content("Giga Depot")
  end
end
