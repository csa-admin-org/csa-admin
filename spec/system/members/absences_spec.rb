# frozen_string_literal: true

require "rails_helper"

describe "Absences", freeze: "2021-06-15" do
  let(:member) { create(:member, :active) }

  before do
    Capybara.app_host = "http://membres.acme.test"
    login(member)
  end

  it "adds new absence" do
    visit "/"

    click_on "Absences"

    fill_in "Début", with: 2.weeks.from_now
    fill_in "Fin", with: 3.weeks.from_now

    fill_in "Remarque", with: "Je serai absent, mais je paie quand même!"

    click_button "Envoyer"

    expect(page).to have_content("Merci de nous avoir prévenus!")
    expect(page).to have_content("Ces paniers ne sont pas remboursés")
    expect(page).to have_content "#{I18n.l(2.weeks.from_now.to_date)} – #{I18n.l(3.weeks.from_now.to_date)}"

    absence = member.absences.last

    note_tooltip = find("#tooltip-absence-#{absence.id}")
    expect(note_tooltip).to have_text("Je serai absent, mais je paie quand même!")

    expect(absence).to have_attributes(
      started_on: 2.weeks.from_now.to_date,
      ended_on: 3.weeks.from_now.to_date,
      note: "Je serai absent, mais je paie quand même!",
      session_id: member.sessions.last.id)
  end

  it "does not show explanation when absences are not billed" do
    current_org.update!(absences_billed: false)

    visit "/absences"

    expect(page).not_to have_content("Ces paniers ne sont pas remboursés")
  end

  it "shows only extra text" do
    default_text = "Ces paniers ne sont pas remboursés"
    extra_text = "Règles spéciales"
    Current.org.update!(absence_extra_text: extra_text)

    visit "/absences"
    expect(page).to have_content default_text
    expect(page).to have_content extra_text

    Current.org.update!(absence_extra_text_only: true)
    visit "/absences"

    expect(page).not_to have_content default_text
    expect(page).to have_content extra_text
  end

  it "lists previous absences" do
    member.absences.build(
      started_on: 3.weeks.ago,
      ended_on: 2.weeks.ago).save!(validate: false)

    visit "/absences"

    expect(page).to have_content "#{I18n.l(3.weeks.ago.to_date)} – #{I18n.l(2.weeks.ago.to_date)}"
  end

  it "redirects to billing when absence is not a feature" do
    current_org.update!(features: [])

    visit "/absences"

    expect(current_path).to eq "/billing"
  end

  specify "list included absences in menu", freeze: "2024-01-01" do
    visit "/absences"
    expect(menu_nav).to include "Absences\n⤷ Prévenez-nous!"

    member.current_membership.update!(absences_included_annually: 4)
    visit "/absences"
    expect(menu_nav).to include "Absences\n⤷ 0 sur 4 annoncées"

    create(:absence, member: member, started_on: "2024-01-08", ended_on: "2024-01-14")
    visit "/absences"
    expect(menu_nav).to include "Absences\n⤷ 1 sur 4 annoncées"
  end
end
