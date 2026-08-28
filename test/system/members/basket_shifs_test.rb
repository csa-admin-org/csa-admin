# frozen_string_literal: true

require "application_system_test_case"

class Members::BasketShiftsTest < ApplicationSystemTestCase
  setup do
    @basket = baskets(:jane_5)
    login(members(:jane))
  end

  test "shifts a basket delivery" do
    org(basket_shifts_annually: 1)
    travel_to @basket.delivery.date - 1.week

    visit "/deliveries"

    click_on "Shift the delivery"

    select "Thursday 9 may"

    assert_changes -> { @basket.reload.quantity }, to: 0 do
      click_on "Submit"
    end

    assert_equal "/deliveries", current_path
    assert_selector ".member-flash", text: "Basket updated successfully."
    assert_text "Shifted on Thursday 9 May"
  end

  test "shifts an included absence" do
    org(basket_shifts_annually: 1)
    @basket.membership.update!(absences_included_annually: 1)
    target = baskets(:jane_6)
    travel_to @basket.delivery.date - 1.week

    visit "/deliveries"

    assert_text "Shift the delivery"
    click_on "Shift the delivery"
    assert_text "This delivery uses an included absence. If you shift it, the target delivery will be billed and the included absence will remain available."

    select "Thursday 9 may"

    assert_changes -> { @basket.reload.quantity }, to: 0 do
      click_on "Submit"
    end

    assert_equal "/deliveries", current_path
    assert target.reload.normal?
    assert target.billable?
    assert_equal 2, target.quantity
    assert_includes menu_nav, "Absences\n⤷ 0 of 1 used"
  end

  test "declines a basket shift" do
    org(basket_shifts_annually: 1)
    travel_to @basket.delivery.date - 1.week

    visit "/deliveries"

    click_on "Shift the delivery"

    select "I don't want to shift my basket"

    assert_no_changes -> { @basket.reload.quantity } do
      click_on "Submit"
    end

    assert_equal "/deliveries", current_path
    assert_selector ".member-flash", text: "Basket updated successfully."
    assert_text "Shift declined"
  end

  test "shift not possible" do
    org(basket_shifts_annually: 1, basket_shift_deadline_in_weeks: 2)
    travel_to @basket.delivery.date + 3.weeks

    visit "/deliveries"

    assert_text "It is no longer possible to shift this basket."
  end

  test "notify member when mail template is active" do
    mail_templates(:absence_baskets_shifted).update!(active: true)

    travel_to "2024-05-01"
    absence = absences(:jane_thursday_5)
    source = baskets(:jane_5)
    target = baskets(:jane_6)
    BasketShift.create!(
      absence: absence,
      membership: source.membership,
      source_delivery: source.delivery,
      target_delivery: target.delivery)
    perform_enqueued_jobs

    assert_equal 1, AbsenceMailer.deliveries.size
    mail = AbsenceMailer.deliveries.last
    assert_equal "Basket(s) shifted", mail.subject
    assert_equal [ absence.member.emails_array.first ], mail.to
    body = mail.html_part.body
    assert_includes body, "Your basket shifts during your absence have been successfully registered"
  end
end
