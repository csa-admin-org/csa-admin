# frozen_string_literal: true

require "application_system_test_case"

class Members::ForcedDeliveriesTest < ApplicationSystemTestCase
  setup do
    travel_to "2024-04-01"
    org(features: [ :absence ], absence_notice_period_in_days: 7)
    @member = members(:jane)
    @membership = @member.current_membership
    @basket = baskets(:jane_10)
  end

  test "shows force button for provisionally absent basket after reminder sent" do
    @membership.update_columns(
      absences_included: 1,
      absences_included_reminder_sent_at: Time.current)
    @basket.update_columns(state: "absent", absence_id: nil, billable: false)

    travel_to @basket.delivery.date - 14.days
    login(@member)
    visit "/deliveries"

    within "#basket_#{@basket.id}" do
      assert_button "Receive this delivery"
    end
  end

  test "force button creates forced delivery" do
    @membership.update_columns(
      absences_included: 1,
      absences_included_reminder_sent_at: Time.current)
    @basket.update_columns(state: "absent", absence_id: nil, billable: false)

    travel_to @basket.delivery.date - 14.days
    login(@member)
    visit "/deliveries"

    assert_difference "ForcedDelivery.count", 1 do
      within "#basket_#{@basket.id}" do
        click_button "Receive this delivery"
      end
    end

    assert_text "Delivery confirmed successfully"
    within "#basket_#{@basket.id}" do
      assert_no_text "Absence"
      assert_no_button "Receive this delivery"
    end
  end

  test "does not show force button before reminder sent" do
    @membership.update_columns(absences_included: 1, absences_included_reminder_sent_at: nil)
    @basket.update_columns(state: "absent", absence_id: nil, billable: false)

    travel_to @basket.delivery.date - 14.days
    login(@member)
    visit "/deliveries"

    within "#basket_#{@basket.id}" do
      assert_no_button "Receive this delivery"
    end
  end

  test "does not show force button for definitely absent basket" do
    @membership.update_columns(
      absences_included: 1,
      absences_included_reminder_sent_at: Time.current)
    # Basket with absence_id set is definitely absent, not provisionally
    @basket.update_columns(state: "absent", absence_id: absences(:jane_thursday_5).id, billable: false)

    travel_to @basket.delivery.date - 14.days
    login(@member)
    visit "/deliveries"

    within "#basket_#{@basket.id}" do
      assert_no_button "Receive this delivery"
    end
  end

  test "shows absences included notice in provisional_absence mode" do
    org(features: [ :absence ], absences_included_mode: "provisional_absence")
    @membership.update_column(:absences_included, 3)

    login(@member)
    visit "/deliveries"

    # Notice should show X of Y format with call to action
    assert_selector "a[href='/absences']", text: /1 of 3.*Still.*2.*to announce!/m
  end

  test "shows absences included notice with warning in provisional_delivery mode" do
    org(features: [ :absence ],
        absences_included_mode: "provisional_delivery",
        absences_included_reminder_weeks_before: 4)
    @membership.update_column(:absences_included, 2)

    login(@member)
    visit "/deliveries"

    # Notice should show warning about unused absences being delivered
    assert_text "delivered at year end"
  end

  test "hides absences included notice when all absences used" do
    org(features: [ :absence ])
    # Jane already has an absence on jane_5/thursday_5, so absences_included_used = 1
    # With absences_included = 1, remaining = 0
    @membership.update_column(:absences_included, 1)

    login(@member)
    visit "/deliveries"

    # Notice should not show when all absences are used (remaining = 0)
    assert_no_selector "a[href='/absences']", text: /to announce/
  end

  test "hides absences included notice when all provisional baskets forced" do
    org(features: [ :absence ], absences_included_mode: "provisional_absence")
    @membership.update_columns(
      absences_included: 2,
      absences_included_reminder_sent_at: Time.current)

    # Create a provisional basket and then force it
    @basket.update_columns(state: "absent", absence_id: nil, billable: false)
    travel_to @basket.delivery.date - 14.days

    # Force the basket
    ForcedDelivery.create!(membership: @membership, delivery: @basket.delivery)
    @basket.reload

    login(@member)
    visit "/deliveries"

    # Notice should be hidden since all provisional baskets are now forced
    assert_no_selector "a[href='/absences']", text: /Request delivery/
  end
end
