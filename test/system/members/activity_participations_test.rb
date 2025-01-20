# frozen_string_literal: true

require "application_system_test_case"

class Members::ActivityParticipationsTest < ApplicationSystemTestCase
  setup { travel_to "2024-06-01" }

  test "adds one new participation" do
    activity = activities(:harvest_afternoon)
    member = members(:john)
    login(member)

    visit "/activity_participations"

    check "activity_participation_activity_ids_#{activity.id}"
    fill_in "activity_participation_participants_count", with: 3
    fill_in "Note", with: "I am coming with my children (3 and 5 years old)"
    click_button "Register"

    assert_text "Thank you for your registration!"

    participation = member.activity_participations.last

    within("ul#coming_participations") do
      assert_text I18n.l(activity.date, format: :medium).capitalize
      assert_text activity.period
      assert_no_selector "span.carpooling svg"

      note_tooltip = find("#tooltip-activity-participation-#{participation.id}")
      assert_equal "I am coming with my children (3 and 5 years old)", note_tooltip.text
    end
    assert_equal "I am coming with my children (3 and 5 years old)", participation.note
    assert_equal 3, participation.participants_count
    assert_nil participation.carpooling_phone
    assert_equal member.sessions.last.id, participation.session_id
  end

  test "adds new participation with carpooling" do
    activity = activities(:harvest_afternoon)
    member = members(:john)
    login(member)

    visit "/activity_participations"

    check "activity_participation_activity_ids_#{activity.id}"
    fill_in "activity_participation_participants_count", with: 3
    check "activity_participation_carpooling"
    fill_in "activity_participation_carpooling_phone", with: "077 447 58 31"
    fill_in "activity_participation_carpooling_city", with: "La Chaux-de-Fonds"
    click_button "Register"

    assert_text "Thank you for your registration!"
    within("ul#coming_participations") do
      assert_selector 'span[title="Carpooling: 077 447 58 31"] svg'
    end
    assert_equal "+41 77 447 58 31", member.activity_participations.last.carpooling_phone
    assert_equal "La Chaux-de-Fonds", member.activity_participations.last.carpooling_city
  end

  test "adds new participation with carpooling (default phone)" do
    activity = activities(:harvest_afternoon)
    member = members(:john)
    member.update(phones: "+41771234567")
    login(member)

    visit "/activity_participations"

    check "activity_participation_activity_ids_#{activity.id}"
    fill_in "activity_participation_participants_count", with: 3
    check "activity_participation_carpooling"

    click_button "Register"

    assert_text "Thank you for your registration!"
    within("ul#coming_participations") do
      assert_selector 'span[title="Carpooling: 077 123 45 67"] svg'
    end
  end

  test "deletes a participation" do
    login(members(:john))
    activity = activities(:harvest)

    visit "/activity_participations"

    within("ul#coming_participations") do
      assert_text I18n.l(activity.date, format: :medium).capitalize
      assert_text activity.period
    end

    click_button "cancel", match: :first

    assert_no_text "For organizational reasons,"
  end

  test "cannot delete a participation when deadline is overdue" do
    login(members(:john))
    org(
      activity_i18n_scope: "basket_preparation",
      activity_participation_deletion_deadline_in_days: 35)
    activity = activities(:harvest)

    visit "/activity_participations"

    within("ul#coming_participations") do
      assert_text I18n.l(activity.date, format: :medium).capitalize
      assert_text activity.period
      assert_no_button "cancel"
    end
    assert_text "For organizational reasons, registrations for basket preparation that take place in less than 35 days can no longer be canceled. In case of hindrance, please contact us contact us."
  end

  test "redirects to billing when activity is not a feature" do
    login(members(:john))
    org(features: [])

    visit "/activity_participations"

    assert_equal "/deliveries", current_path
  end
end
