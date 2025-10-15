# frozen_string_literal: true

require "test_helper"

class AbsenceTest < ActiveSupport::TestCase
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

  test "notifies admin with new_absence notifications on when created" do
    admin1 = admins(:ultra)
    admin2 = admins(:super)
    admin3 = admins(:external)
    admin1.update_column(:notifications, %w[new_absence])
    admin2.update_column(:notifications, %w[new_absence_with_note])
    admin3.update_column(:notifications, %w[])

    absence = create_absence(
      member: members(:john),
      note: " ",
      started_on: 1.week.from_now,
      ended_on: 2.weeks.from_now)
    perform_enqueued_jobs

    assert_equal 1, AdminMailer.deliveries.size
    mail = AdminMailer.deliveries.last
    assert_equal "New absence", mail.subject
    assert_equal [ admin1.email ], mail.to
    body = mail.html_part.body
    assert_includes body, admin1.name
    assert_includes body, absence.member.name
    assert_includes body, I18n.l(absence.started_on)
    assert_includes body, I18n.l(absence.ended_on)
    assert_not_includes body, "Member's note:"
  end

  test "only notifies admin with new_absence_with_note notifications when note is present" do
    admin1 = admins(:ultra)
    admin2 = admins(:super)
    admin3 = admins(:external)
    admin1.update_column(:notifications, %w[new_absence])
    admin2.update_column(:notifications, %w[new_absence_with_note])
    admin3.update_column(:notifications, %w[])

    absence = create_absence(
      admin: admin1,
      member: members(:john),
      note: "A Super Note!",
      started_on: 1.week.from_now,
      ended_on: 2.weeks.from_now)
    perform_enqueued_jobs

    assert_equal 1, AdminMailer.deliveries.size
    mail = AdminMailer.deliveries.last
    assert_equal "New absence", mail.subject
    assert_equal [ admin2.email ], mail.to
    body = mail.html_part.body
    assert_includes body, admin2.name
    assert_includes body, absence.member.name
    assert_includes body, I18n.l(absence.started_on)
    assert_includes body, I18n.l(absence.ended_on)
    assert_includes body, "Member's note:"
    assert_includes body, "A Super Note!"
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
end
