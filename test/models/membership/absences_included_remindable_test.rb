# frozen_string_literal: true

require "test_helper"

class Membership::AbsencesIncludedRemindableTest < ActiveSupport::TestCase
  setup do
    travel_to "2024-01-01"
    org(
      trial_baskets_count: 0,
      absences_billed: true,
      absences_included_mode: "provisional_absence"
    )
    # Ensure the mail template exists and is active
    MailTemplate.find_or_create_by!(title: "absence_included_reminder").update!(active: true)
  end

  test "send_absences_included_reminders does nothing when absence feature is disabled" do
    org(features: [])
    membership = memberships(:john)
    membership.update!(absences_included_annually: 2)

    Membership.send_absences_included_reminders

    assert_nil membership.reload.absences_included_reminder_sent_at
  end

  test "send_absences_included_reminders does nothing when membership has no absences_included" do
    membership = memberships(:john)
    assert_equal 0, membership.absences_included

    travel_to "2024-12-15"
    Membership.send_absences_included_reminders

    assert_nil membership.reload.absences_included_reminder_sent_at
  end

  test "send_absences_included_reminders does nothing when remindable_on not yet reached" do
    membership = memberships(:john)
    membership.update!(absences_included_annually: 2)

    first_provisional = membership.baskets.coming.provisionally_absent.first
    remindable_on = first_provisional.delivery.date - Current.org.absences_included_reminder_period

    # Stay before the remindable_on date
    travel_to remindable_on - 1.day

    assert_no_difference "MembershipMailer.deliveries.size" do
      Membership.send_absences_included_reminders
      perform_enqueued_jobs
    end

    assert_nil membership.reload.absences_included_reminder_sent_at
  end

  test "send_absences_included_reminders sends reminder when remindable_on is reached" do
    membership = memberships(:john)
    membership.update!(absences_included_annually: 2)

    first_provisional = membership.baskets.coming.provisionally_absent.first
    assert_not_nil first_provisional
    remindable_on = first_provisional.delivery.date - Current.org.absences_included_reminder_period

    travel_to remindable_on
    assert_difference "MembershipMailer.deliveries.size", 1 do
      Membership.send_absences_included_reminders
      perform_enqueued_jobs
    end

    assert_not_nil membership.reload.absences_included_reminder_sent_at
  end

  test "send_absences_included_reminders skips membership if reminder already sent" do
    membership = memberships(:john)
    membership.update!(absences_included_annually: 2)
    membership.update_column(:absences_included_reminder_sent_at, 1.day.ago)

    first_provisional = membership.baskets.coming.provisionally_absent.first
    remindable_on = first_provisional.delivery.date - Current.org.absences_included_reminder_period

    travel_to remindable_on
    assert_no_difference "MembershipMailer.deliveries.size" do
      Membership.send_absences_included_reminders
      perform_enqueued_jobs
    end
  end

  test "provisional_absence mode: sends reminder only, does not create forced deliveries" do
    org(absences_included_mode: "provisional_absence")
    membership = memberships(:john)
    membership.update!(absences_included_annually: 2)

    provisional_count = membership.baskets.provisionally_absent.count
    assert provisional_count > 0

    first_provisional = membership.baskets.provisionally_absent.first
    remindable_on = first_provisional.delivery.date - 2.weeks

    travel_to remindable_on
    Membership.send_absences_included_reminders

    membership.reload
    assert_equal 0, membership.forced_deliveries.count
    assert_equal provisional_count, membership.baskets.provisionally_absent.count
    assert_not_nil membership.absences_included_reminder_sent_at
  end

  test "provisional_delivery mode: creates forced deliveries for all provisional baskets" do
    org(absences_included_mode: "provisional_delivery")
    membership = memberships(:john)
    membership.update!(absences_included_annually: 2)

    provisional_count = membership.baskets.provisionally_absent.count
    assert provisional_count > 0

    first_provisional = membership.baskets.coming.provisionally_absent.first
    remindable_on = first_provisional.delivery.date - Current.org.absences_included_reminder_period

    travel_to remindable_on
    Membership.send_absences_included_reminders

    membership.reload
    assert_equal provisional_count, membership.forced_deliveries.count
    assert_equal 0, membership.baskets.provisionally_absent.count
    assert_equal provisional_count, membership.baskets.forced.count
    assert_not_nil membership.absences_included_reminder_sent_at
  end

  test "send_absences_included_reminder! sends reminder when remindable_on is reached" do
    membership = memberships(:john)
    membership.update!(absences_included_annually: 2)

    first_provisional = membership.baskets.coming.provisionally_absent.first
    remindable_on = first_provisional.delivery.date - Current.org.absences_included_reminder_period

    travel_to remindable_on
    assert_difference "MembershipMailer.deliveries.size", 1 do
      membership.send_absences_included_reminder!
      perform_enqueued_jobs
    end

    assert_not_nil membership.reload.absences_included_reminder_sent_at
  end

  test "send_absences_included_reminder! does nothing before remindable_on" do
    membership = memberships(:john)
    membership.update!(absences_included_annually: 2)

    first_provisional = membership.baskets.coming.provisionally_absent.first
    remindable_on = first_provisional.delivery.date - Current.org.absences_included_reminder_period

    # Stay well before the remindable_on date
    travel_to remindable_on - 1.day
    assert_no_difference "MembershipMailer.deliveries.size" do
      membership.send_absences_included_reminder!
      perform_enqueued_jobs
    end

    assert_nil membership.reload.absences_included_reminder_sent_at
  end

  test "absences_included_remindable_on returns correct date" do
    membership = memberships(:john)
    membership.update!(absences_included_annually: 2)

    first_provisional = membership.baskets.coming.provisionally_absent.first
    expected_date = first_provisional.delivery.date - Current.org.absences_included_reminder_period

    assert_equal expected_date, membership.absences_included_remindable_on
  end

  test "absences_included_remindable_on returns nil when no provisional baskets" do
    membership = memberships(:john)
    assert_equal 0, membership.absences_included

    assert_nil membership.absences_included_remindable_on
  end

  test "absences_included_remindable_on returns nil when all provisional baskets are in the past" do
    membership = memberships(:john)
    membership.update!(absences_included_annually: 2)

    # Travel past all provisional basket delivery dates
    last_provisional = membership.baskets.provisionally_absent.last
    travel_to last_provisional.delivery.date + 1.day

    assert_nil membership.absences_included_remindable_on
  end

  test "absences_included_remindable_on finds first coming basket even if earlier ones are past" do
    membership = memberships(:john)
    membership.update!(absences_included_annually: 2)

    first_provisional = membership.baskets.provisionally_absent.first
    # Travel past the first provisional but before the second
    travel_to first_provisional.delivery.date + 1.day

    # Should still find the next coming provisional basket
    second_provisional = membership.baskets.coming.provisionally_absent.first
    expected_date = second_provisional.delivery.date - Current.org.absences_included_reminder_period
    assert_equal expected_date, membership.absences_included_remindable_on
  end

  test "absences_included_reminded? returns true when reminder sent" do
    membership = memberships(:john)
    membership.update_column(:absences_included_reminder_sent_at, Time.current)

    assert membership.absences_included_reminded?
  end

  test "absences_included_reminded? returns false when reminder not sent" do
    membership = memberships(:john)

    assert_not membership.absences_included_reminded?
  end

  test "send_absences_included_reminders skips past memberships" do
    membership = memberships(:john)
    membership.update!(absences_included_annually: 2)

    # Travel past the membership end date
    travel_to "2025-02-01"
    assert_no_difference "MembershipMailer.deliveries.size" do
      Membership.send_absences_included_reminders
      perform_enqueued_jobs
    end

    assert_nil membership.reload.absences_included_reminder_sent_at
  end

  test "absences_included_remindable scope returns eligible memberships" do
    membership = memberships(:john)
    membership.update!(absences_included_annually: 2)

    assert_includes Membership.absences_included_remindable, membership
  end

  test "absences_included_remindable scope excludes memberships without absences_included" do
    membership = memberships(:john)
    assert_equal 0, membership.absences_included

    assert_not_includes Membership.absences_included_remindable, membership
  end

  test "absences_included_remindable scope excludes memberships already reminded" do
    membership = memberships(:john)
    membership.update!(absences_included_annually: 2)
    membership.update_column(:absences_included_reminder_sent_at, Time.current)

    assert_not_includes Membership.absences_included_remindable, membership
  end

  test "absences_included_used returns count of definitely absent baskets" do
    membership = memberships(:john)
    membership.update!(absences_included_annually: 4)

    assert_equal 0, membership.absences_included_used

    # Create an absence for the first basket
    first_basket = membership.baskets.first
    Absence.create!(
      member: membership.member,
      started_on: first_basket.delivery.date,
      ended_on: first_basket.delivery.date + 1.day
    )

    assert_equal 1, membership.absences_included_used
  end

  test "absences_included_remaining returns difference between included and used" do
    membership = memberships(:john)
    membership.update!(absences_included_annually: 4)

    assert_equal 4, membership.absences_included_remaining

    # Create an absence for the first basket
    first_basket = membership.baskets.first
    Absence.create!(
      member: membership.member,
      started_on: first_basket.delivery.date,
      ended_on: first_basket.delivery.date + 1.day
    )

    assert_equal 3, membership.absences_included_remaining
  end

  test "absences_included_remaining never goes negative" do
    membership = memberships(:john)
    membership.update!(absences_included_annually: 1)

    # Create 2 absences when only 1 is included
    first_basket = membership.baskets.first
    second_basket = membership.baskets.second
    Absence.create!(
      member: membership.member,
      started_on: first_basket.delivery.date,
      ended_on: first_basket.delivery.date + 1.day
    )
    Absence.create!(
      member: membership.member,
      started_on: second_basket.delivery.date,
      ended_on: second_basket.delivery.date + 1.day
    )

    assert_equal 2, membership.absences_included_used
    assert_equal 0, membership.absences_included_remaining
  end
end
