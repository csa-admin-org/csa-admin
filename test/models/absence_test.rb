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
end
