# frozen_string_literal: true

require "application_system_test_case"

class Members::AbsencesTest < ApplicationSystemTestCase
  setup { travel_to "2024-01-01" }

  test "adds new absence" do
    member = members(:john)
    login(member)

    visit "/"
    click_on "Absences"

    fill_in "Start", with: 2.weeks.from_now
    fill_in "End", with: 3.weeks.from_now
    fill_in "Note", with: "I will be absent, but I will still pay!"

    click_button "Submit"

    assert_text "Thank you for informing us!"
    assert_text "These baskets are not refunded"
    assert_text "#{I18n.l(2.weeks.from_now.to_date)} – #{I18n.l(3.weeks.from_now.to_date)}"

    absence = member.absences.last
    note_tooltip = find("#tooltip-absence-#{absence.id}")
    assert_equal "I will be absent, but I will still pay!", note_tooltip.text

    assert_equal 2.weeks.from_now.to_date, absence.started_on
    assert_equal 3.weeks.from_now.to_date, absence.ended_on
    assert_equal "I will be absent, but I will still pay!", absence.note
    assert_equal member.sessions.last.id, absence.session_id
  end

  test "does not show explanation when absences are not billed" do
    org(absences_billed: false)
    login(members(:john))

    visit "/absences"
    assert_no_text "These baskets are not refunded"
  end

  test "shows only extra text" do
    login(members(:john))
    default_text = "These baskets are not refunded"
    extra_text = "Special rules"
    Current.org.update!(absence_extra_text: extra_text)

    visit "/absences"
    assert_text default_text
    assert_text extra_text

    org(absence_extra_text_only: true)
    visit "/absences"
    assert_no_text default_text
    assert_text extra_text
  end

  test "lists previous absences" do
    login(members(:john))
    create_absence(started_on: "2024-04-01", ended_on: "2024-04-07")

    visit "/absences"
    assert_text "1 April 2024 – 7 April 2024 (1 delivery)"
  end

  test "redirects to billing when absence is not a feature" do
    org(features: [])
    login(members(:john))

    visit "/absences"
    assert_equal "/deliveries", current_path
  end

  test "list included absences in menu" do
    member = members(:john)
    login(member)

    visit "/absences"
    assert_includes menu_nav, "Absences\n⤷ Let us know!"

    member.current_membership.update!(absences_included_annually: 4)
    visit "/absences"
    assert_includes menu_nav, "Absences\n⤷ 0 of 4 reported"

    create_absence(started_on: "2024-04-01", ended_on: "2024-04-06")
    visit "/absences"
    assert_includes menu_nav, "Absences\n⤷ 1 of 4 reported"
  end
end
