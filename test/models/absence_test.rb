# frozen_string_literal: true

require "test_helper"

class AbsenceTest < ActiveSupport::TestCase
  test "updates absent baskets state" do
    travel_to "2024-01-01"
    member = members(:john)
    current_membership = memberships(:john)
    future_membership = memberships(:john_future)

    assert_equal 0, current_membership.baskets.absent.count
    assert_equal 0, future_membership.baskets.absent.count

    absence = create_absence(
      member: member,
      started_on: "2024-05-01",
      ended_on: "2025-05-01")

    assert_equal 9, absence.baskets.count
    assert_equal 5, current_membership.reload.baskets.absent.count
    assert_equal 4, future_membership.reload.baskets.absent.count

    absence.update!(
      started_on: "2024-08-01",
      ended_on: "2025-04-15")

    assert_equal 2, absence.baskets.count
    assert_equal 0, current_membership.reload.baskets.absent.count
    assert_equal 2, future_membership.reload.baskets.absent.count
  end

  test "updates membership price when absent baskets are not billed" do
    travel_to "2024-01-01"
    Current.org.update_column(:absences_billed, false)

    membership = memberships(:john)

    assert_difference -> { membership.reload.price }, -100 do
      create_absence(
        member: members(:john),
        started_on: "2024-05-01",
        ended_on: "2024-12-01")
    end
    assert_equal 5, membership.baskets.billable.count
  end

  test "notify member when mail template is active" do
    mail_templates(:absence_created).update!(active: true)

    travel_to "2024-05-01"
    absence = create_absence(
      admin: admins(:ultra),
      member: members(:john),
      note: "A Super Note!",
      started_on: 1.week.from_now,
      ended_on: 2.weeks.from_now)
    perform_enqueued_jobs

    assert_equal 1, AbsenceMailer.deliveries.size
    mail = AbsenceMailer.deliveries.last
    assert_equal "Absence confirmation", mail.subject
    assert_equal [ absence.member.emails_array.first ], mail.to
    body = mail.html_part.body
    assert_includes body, "Period:</strong> 8 May 2024 to 15 May 2024"
    assert_includes body, "Affected deliveries:</strong> 1"
  end

  test "does not notify member when destroyed" do
    mail_templates(:absence_created).update!(active: true)

    travel_to "2024-05-01"
    absence = create_absence(
      admin: admins(:ultra),
      member: members(:john),
      started_on: 1.week.from_now,
      ended_on: 2.weeks.from_now)
    clear_enqueued_jobs

    assert_no_difference -> { MailDelivery.count } do
      absence.destroy!
    end
    assert_no_enqueued_jobs only: MailDelivery::ProcessJob
  end

  test "validates started_on and ended_on dates when submitted by member" do
    travel_to "2024-01-15"
    absence = Absence.new(
      member: members(:john),
      started_on: 6.days.from_now,
      ended_on: 2.years.from_now)

    assert_not absence.valid?
    assert_includes absence.errors[:started_on], "must be after or equal to 22 January 2024"
    assert_includes absence.errors[:ended_on], "must be before 19 January 2025"
  end

  test "does not validate started_on and ended_on dates when submitted by admin" do
    absence = Absence.new(
      member: members(:john),
      admin: admins(:ultra),
      started_on: Date.current,
      ended_on: 2.years.from_now)

    assert absence.valid?
  end

  test "admin cannot create an absence that starts before the current fiscal year" do
    travel_to "2024-06-01"
    absence = Absence.new(
      member: members(:john),
      admin: admins(:ultra),
      started_on: "2023-12-01",
      ended_on: "2023-12-15")

    assert_not absence.valid?
    assert_includes absence.errors[:started_on], "must be in the current fiscal year"
  end

  test "a past fiscal year absence cannot be edited, including the note" do
    absence = travel_to("2023-06-01") {
      create_absence(started_on: "2023-06-01", ended_on: "2023-06-15", note: "Holiday")
    }
    travel_to "2024-06-01"
    Current.reset

    assert_not absence.can_update?
    assert_not absence.can_destroy?
    assert_not absence.update(note: "Changed")
    assert_includes absence.errors[:base],
      "This absence ended before the current fiscal year and cannot be changed"
    assert_equal "Holiday", absence.reload.note
  end

  test "a spanning absence can end on the last day of the previous fiscal year and no earlier" do
    travel_to "2024-06-01"
    absence = travel_to("2023-12-01") {
      create_absence(started_on: "2023-12-15", ended_on: "2024-01-15", note: "Away")
    }
    Current.reset

    assert absence.can_update?
    assert_not absence.can_destroy?
    assert absence.started_on_locked?
    assert absence.update(ended_on: "2024-02-01")
    assert_equal Date.new(2024, 2, 1), absence.reload.ended_on

    assert_not absence.update(ended_on: Date.new(2023, 12, 30))
    assert_includes absence.errors[:ended_on], "must be on or after 31 December 2023"
    assert_equal Date.new(2024, 2, 1), absence.reload.ended_on

    assert absence.update(ended_on: Date.new(2023, 12, 31), note: "Back sooner")
    assert_equal Date.new(2023, 12, 31), absence.ended_on
    assert_equal "Back sooner", absence.note
    assert_not absence.can_update?
  end

  test "a spanning absence cannot move its start" do
    travel_to "2024-06-01"
    absence = travel_to("2023-12-01") {
      create_absence(started_on: "2023-12-15", ended_on: "2024-01-15")
    }
    Current.reset

    assert_not absence.can_destroy?
    assert_not absence.update(started_on: "2024-01-02")
    assert_includes absence.errors[:started_on], "cannot be changed"
    assert_equal Date.new(2023, 12, 15), absence.reload.started_on
  end

  test "a current fiscal year absence stays fully editable" do
    travel_to "2024-06-01"
    absence = create_absence(started_on: "2024-06-10", ended_on: "2024-06-20", note: "Trip")

    assert absence.can_update?
    assert absence.can_destroy?
    assert absence.update(started_on: "2024-07-01", ended_on: "2024-07-08", note: "Later")
    assert_equal Date.new(2024, 7, 1), absence.reload.started_on
    assert_equal "Later", absence.note
    assert absence.destroy
  end

  test "a current absence cannot be moved so that it starts last fiscal year" do
    travel_to "2024-06-01"
    absence = create_absence(started_on: "2024-06-10", ended_on: "2024-06-20")

    assert_not absence.update(started_on: "2023-12-20", ended_on: "2024-06-20")
    assert_includes absence.errors[:started_on], "must be in the current fiscal year"
    assert_equal Date.new(2024, 6, 10), absence.reload.started_on
  end

  test "fiscal year boundary is the configured year, not 31 December" do
    travel_to "2024-06-01"
    org(fiscal_year_start_month: 4)
    member = create_member
    absence = travel_to("2024-03-01") {
      Current.reset
      create_absence(member: member, started_on: "2024-03-10", ended_on: "2024-04-10")
    }
    Current.reset

    assert_not absence.update(ended_on: Date.new(2024, 3, 30))
    assert_includes absence.errors[:ended_on], "must be on or after 31 March 2024"
    assert_equal Date.new(2024, 4, 10), absence.reload.ended_on

    assert absence.update(ended_on: Date.new(2024, 3, 31))
    assert_equal Date.new(2024, 3, 31), absence.ended_on
  end

  test "admin can still skip the notice period inside the current fiscal year" do
    travel_to "2024-06-01"
    absence = Absence.new(
      member: members(:john),
      admin: admins(:ultra),
      started_on: Date.current,
      ended_on: Date.current + 2.days)

    assert absence.valid?
    assert_not Absence.new(
      member: members(:john),
      started_on: Date.current,
      ended_on: Date.current + 2.days).valid?
  end
end
