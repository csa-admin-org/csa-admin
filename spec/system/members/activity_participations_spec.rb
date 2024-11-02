# frozen_string_literal: true

require "rails_helper"

describe "Activity Participation" do
  let(:member) { create(:member) }

  before do
    Capybara.app_host = "http://membres.acme.test"
    login(member)
  end

  it "adds one new participation" do
    activity = create(:activity, date: 4.days.from_now)

    visit "/activity_participations"

    check "activity_participation_activity_ids_#{activity.id}"
    fill_in "activity_participation_participants_count", with: 3
    fill_in "Remarque", with: "Je viens avec mes enfants (3 et 5 ans)"
    click_button "Inscription"

    expect(page).to have_content("Merci pour votre inscription!")

    participation = member.activity_participations.last

    within("ul#coming_participations") do
      expect(page).to have_content I18n.l(activity.date, format: :medium).capitalize
      expect(page).to have_content activity.period
      expect(page).not_to have_selector("span.carpooling svg")

      note_tooltip = find("#tooltip-activity-participation-#{participation.id}")
      expect(note_tooltip).to have_text("Je viens avec mes enfants (3 et 5 ans)")
    end
    expect(participation).to have_attributes(
      note: "Je viens avec mes enfants (3 et 5 ans)",
      participants_count: 3,
      carpooling_phone: nil,
      session_id: member.sessions.last.id)
  end

  it "adds new participation with carpooling" do
    activity = create(:activity, date: 4.days.from_now)

    visit "/activity_participations"

    check "activity_participation_activity_ids_#{activity.id}"
    fill_in "activity_participation_participants_count", with: 3
    check "activity_participation_carpooling"
    fill_in "activity_participation_carpooling_phone", with: "077 447 58 31"
    fill_in "activity_participation_carpooling_city", with: "La Chaux-de-Fonds"
    click_button "Inscription"

    expect(page).to have_content("Merci pour votre inscription!")
    within("ul#coming_participations") do
      expect(page).to have_selector('span[title="Covoiturage: 077 447 58 31"] svg')
    end
    expect(member.activity_participations.last).to have_attributes(
      carpooling_phone: "+41 77 447 58 31", # phormatted
      carpooling_city: "La Chaux-de-Fonds")
  end

  it "adds new participation with carpooling (default phone)" do
    member.update(phones: "+41771234567")
    activity = create(:activity, date: 4.days.from_now)

    visit "/activity_participations"

    check "activity_participation_activity_ids_#{activity.id}"
    fill_in "activity_participation_participants_count", with: 3
    check "activity_participation_carpooling"

    click_button "Inscription"

    expect(page).to have_content("Merci pour votre inscription!")
    within("ul#coming_participations") do
      expect(page).to have_selector('span[title="Covoiturage: 077 123 45 67"] svg')
    end
  end

  it "deletes a participation" do
    activity = create(:activity_participation, member: member).activity

    visit "/activity_participations"

    within("ul#coming_participations") do
      expect(page).to have_content I18n.l(activity.date, format: :medium).capitalize
      expect(page).to have_content activity.period
    end

    click_button "annuler", match: :first

    expect(page).not_to have_content "Pour des raisons d'organisation,"
  end

  it "cannot delete a participation when deadline is overdue" do
    Current.org.update!(
      activity_i18n_scope: "basket_preparation",
      activity_participation_deletion_deadline_in_days: 30)
    activity = create(:activity, date: 29.days.from_now)
    create(:activity_participation,
      member: member,
      activity: activity,
      created_at: 25.hours.ago)

    visit "/activity_participations"

    within("ul#coming_participations") do
      expect(page).to have_content I18n.l(activity.date, format: :medium).capitalize
      expect(page).to have_content activity.period
      expect(page).not_to have_content "annuler"
    end
    expect(page).to have_content "Pour des raisons d'organisation, les inscriptions aux mises en panier qui ont lieu dans moins de 30 jours ne peuvent plus être annulées. En cas d'empêchement, merci de nous contacter."
  end

  it "redirects to billing when activity is not a feature" do
    current_org.update!(features: [])

    visit "/activity_participations"

    expect(current_path).to eq "/billing"
  end
end
