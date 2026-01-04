# frozen_string_literal: true

require "test_helper"

class Notification::MembershipRenewalReminderTest < ActiveSupport::TestCase
  test "notify sends renewal reminder emails" do
    org(open_renewal_reminder_sent_after_in_days: 10)
    mail_templates(:membership_renewal_reminder).update!(active: true)
    member = create_member(emails: "anybody@doe.com")

    travel_to "2024-01-01"
    create_membership(renewal_opened_at: nil)
    create_membership(renewal_opened_at: "2024-09-01", member: create_member).update_columns(renewed_at: "2024-09-02")
    create_membership(renewal_opened_at: "2024-09-01", member: member)
    create_membership(renewal_opened_at: "2024-09-01", member: create_member, renewal_reminder_sent_at: "2024-09-10")
    travel_to "2023-01-01"
    create_membership(renewal_opened_at: "2024-09-01")

    travel_to "2024-09-11"
    assert_difference -> { MembershipMailer.deliveries.size }, 1 do
      Notification::MembershipRenewalReminder.notify
      perform_enqueued_jobs
    end

    mail = MembershipMailer.deliveries.last
    assert_equal "Renew your membership (reminder)", mail.subject
    assert_equal [ "anybody@doe.com" ], mail.to
  end
end
